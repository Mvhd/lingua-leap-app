import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lingua_leap/app/theme/theme.dart';
import 'package:lingua_leap/models/game_model.dart';
import 'package:lingua_leap/models/group_model.dart';
import 'package:lingua_leap/models/user_model.dart';
import 'package:lingua_leap/features/game/services/game_service.dart';
import 'package:lingua_leap/features/auth/services/user_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../l10n/app_localizations.dart';
import 'package:lingua_leap/models/language_strength.dart';

import '../../../services/language_service.dart';

class GameView extends StatefulWidget {
  final String gameId;
  final String? groupId;
  final GroupModel group;
  final Function(bool)? onExit;

  const GameView({
    super.key,
    required this.gameId,
    this.groupId,
    required this.group,
    this.onExit,
  });

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final UserService _userService = UserService();
  final SpeechToText _speechToText = SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isListening = false;
  String _lastWords = "";
  bool _speechEnabled = false;
  bool? _lastTurnCorrect;
  bool _isSubmitting = false;
  LanguageStrength userStrength = LanguageStrength.beginner;
  late AnimationController _animationController;
  Map<String, UserModel> _playerProfiles = {};
  bool _cancellationSheetShown = false;
  List<String>? _lastPlayerIds;
  StreamSubscription<GameModel>? _gameSubscription;

  // Timer state
  Timer? _countdownTimer;
  int _secondsRemaining = 30;
  int _waitingSecondsElapsed = 0;
  final int _turnDuration = 30;

  // Preview Mode state
  bool _isPreviewMode = false;
  String? _tempAudioPath;
  bool _isPlaying = false;


  Future<void> _loadUserStrength() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await _userService.getUserProfile(uid);
      if (user != null && user.languageStrength != null && mounted) {
        setState(() {
          userStrength = user.languageStrength!;
        });
      }
    }
  }

  Future<void> _loadPlayerProfiles(List<String> playerIds) async {
    bool allLoaded = playerIds.every((id) => _playerProfiles.containsKey(id));
    if (allLoaded) return;
    
    final profiles = await Future.wait(
      playerIds.map((id) => _userService.getUserProfile(id))
    );
    
    if (mounted) {
      setState(() {
        _playerProfiles = {
          for (var profile in profiles.whereType<UserModel>())
            profile.uid: profile
        };
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initSpeech();
    _loadUserStrength();
    _startGameStateListener();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    
    final String h = hours.toString().padLeft(2, '0');
    final String m = minutes.toString().padLeft(2, '0');
    final String s = seconds.toString().padLeft(2, '0');
    
    return hours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _startGameStateListener() {
    _gameSubscription = _gameService
        .getGameStateStream(widget.groupId, widget.gameId)
        .listen((game) {
      _handleTimerSync(game);
      
      if (_lastPlayerIds != null) {
        final leftIds = _lastPlayerIds!.where((id) => !game.players.contains(id)).toList();
        for (final id in leftIds) {
          final profile = _playerProfiles[id];
          if(!mounted) return;
          final name = profile?.displayName ?? AppLocalizations.of(context)!.player;
          
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                description: Text(AppLocalizations.of(context)!.playerLeftGame(name)),
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
              ),
            );
          }
        }
      }
      _lastPlayerIds = List.from(game.players);
    });
  }

  void _handleTimerSync(GameModel game) {
    if (game.status != GameStatus.inProgress) {
      _countdownTimer?.cancel();
      return;
    }

    if (game.turnStartTime != null) {
      final now = DateTime.now();
      final startTime = game.turnStartTime!.toDate();
      final elapsed = now.difference(startTime).inSeconds;
      final remaining = _turnDuration - elapsed;

      if (mounted) {
        setState(() {
          _secondsRemaining = remaining > 0 ? remaining : 0;
          _waitingSecondsElapsed = 0; 
        });
      }

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            timer.cancel();
            _onTurnTimeout(game);
          }
        });
      });
    } else if (game.waitingStartTime != null) {
      final now = DateTime.now();
      final startTime = game.waitingStartTime!.toDate();
      final elapsed = now.difference(startTime).inSeconds;

      if (mounted) {
        setState(() {
          _waitingSecondsElapsed = elapsed;
          _secondsRemaining = _turnDuration;
        });
      }

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _waitingSecondsElapsed++;
        });
      });
    } else {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _secondsRemaining = _turnDuration;
          _waitingSecondsElapsed = 0;
        });
      }
    }
  }

  void _onTurnTimeout(GameModel game) {
    if (_isSubmitting) {
      debugPrint("TIMEOUT: Ignoring timeout because submission is in progress.");
      return;
    }
    final bool isMyTurn = game.currentPlayerId == _currentUserId;
    final bool isHost = game.players.first == _currentUserId;

    if (isMyTurn || (isHost && _secondsRemaining <= 0)) {
      debugPrint("TURN TIMEOUT TRIGGERED");
      _gameService.handleTurnTimeout(game);
      if (mounted) {
        setState(() {
          _isPreviewMode = false;
          _lastWords = "";
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gameSubscription?.cancel();
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    debugPrint("SPEECH: Initializing...");
    var status = await Permission.microphone.request();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    
    if (status.isGranted) {
      try {
        _speechEnabled = await _speechToText.initialize(
          onStatus: (status) {
            debugPrint("SPEECH STATUS: $status");
            if ((status == 'done' || status == 'notListening' || status == 'error') && mounted) {
              setState(() {
                _isListening = false;
                _animationController.stop();
                _animationController.reset();
              });
            }
          },
          onError: (errorNotification) {
            debugPrint("SPEECH ERROR: ${errorNotification.errorMsg}");
            if (mounted) {
              setState(() {
                _isListening = false;
                _animationController.stop();
                _animationController.reset();
              });
            }
          },
        );
        debugPrint("SPEECH: Initialization result: $_speechEnabled");
      } catch (e) {
        debugPrint("SPEECH ERROR: Exception during init: $e");
        _speechEnabled = false;
      }
      if (mounted) setState(() {});
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ShadDialog(
            closeIcon: ShadIconButton.ghost(icon: const Icon(LucideIcons.x,size: 0,),enabled: false,),
            removeBorderRadiusWhenTiny: false,
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            title: Text(l10n.microphonePermission),
            description: Text(l10n.micPermissionDetailed),
            actions: [
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  ShadButton.ghost(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                  ShadButton(onPressed: () => openAppSettings(), child: Text(l10n.openSettings)),
                ],
              ),
            ],
          ),
        );
      }
    }
  }

  void _startListening(GameModel game) async {
    final l10n = AppLocalizations.of(context)!;
    debugPrint("SPEECH: _startListening called. Enabled: $_speechEnabled, Listening: ${_speechToText.isListening}");
    
    if (!_speechEnabled) {
      debugPrint("SPEECH: Not enabled, re-initializing...");
      _initSpeech();
      return;
    }

    if (_speechToText.isListening) {
      debugPrint("SPEECH: Already listening, ignoring request.");
      return;
    }

    // 🔥 TIMER START LOGIC: Starts ONLY when the player press/holds the speak button for the first time
    if (game.turnStartTime == null) {
      await _gameService.startTurn(widget.groupId, widget.gameId);
    }

    try {
      final String languageName = widget.group.currentLanguage;
      final LanguageService langService = LanguageService();
      final String? groupLangCode = await langService.getLanguageCode(languageName);
      
      String targetLocaleId = 'en-US';
      try {
        final systemLocales = await _speechToText.locales();
        if (groupLangCode != null && groupLangCode.isNotEmpty) {
          final codeLower = groupLangCode.toLowerCase();
          final match = systemLocales.firstWhere(
            (loc) => loc.localeId.toLowerCase().startsWith(codeLower) ||
                     loc.localeId.toLowerCase().contains(codeLower) ||
                     loc.name.toLowerCase().contains(languageName.toLowerCase()),
            orElse: () => systemLocales.firstWhere(
              (loc) => loc.localeId.startsWith('en'),
              orElse: () => systemLocales.isNotEmpty ? systemLocales.first : LocaleName('en-US', 'English'),
            ),
          );
          targetLocaleId = match.localeId;
        }
      } catch (e) {
        debugPrint("SPEECH: Error fetching system locales: $e");
      }

      debugPrint("SPEECH: Starting with locale: $targetLocaleId");

      if (mounted) {
        setState(() {
          _lastWords = "";
          _isListening = true;
        });
        _animationController.repeat(reverse: true);
      }

      await _speechToText.listen(
        onResult: (result) {
          _onSpeechResult(result);
        },
        listenOptions: SpeechListenOptions(
          localeId: targetLocaleId,
          listenFor: const Duration(seconds: 45), 
          pauseFor: const Duration(seconds: 10), 
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint("SPEECH ERROR: Failed to start listening: $e");
      if (mounted) {
        setState(() => _isListening = false);
        ShadToaster.of(context).show(
          ShadToast(
            title: Text(l10n.errorTitle),
            description: Text(e.toString()),
            backgroundColor: Colors.redAccent.shade100,
          ),
        );
      }
    }
  }

  void _stopListening() async {
    debugPrint("SPEECH: _stopListening called. Current _lastWords='$_lastWords'");
    try {
      await _speechToText.stop();
    } catch (e) {
      debugPrint("SPEECH ERROR: Failed to stop: $e");
    }
    
    // Give speech_to_text time to process and deliver the final result callback
    await Future.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      setState(() {
        _isListening = false;
        _animationController.stop();
        _animationController.reset();
        
        if (_lastWords.trim().isNotEmpty) {
          _isPreviewMode = true;
          debugPrint("SPEECH: Captured words: '$_lastWords'. Entering preview mode.");
        } else {
          debugPrint("SPEECH: No words recognized, staying in active turn mode.");
        }
      });
    }
  }

  void _playRecording() async {
    if (_tempAudioPath != null) {
      await _audioPlayer.play(DeviceFileSource(_tempAudioPath!));
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_isSubmitting) return;
    debugPrint("SPEECH RESULT: '${result.recognizedWords}' (final: ${result.finalResult})");
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  void _submitPreview(GameModel currentGame) async {
    debugPrint("GAME: _submitPreview triggered. _lastWords='$_lastWords'");
    if (_lastWords.isEmpty) {
      debugPrint("GAME: Cannot submit, _lastWords is empty.");
      return;
    }

    if (_isSubmitting) {
      debugPrint("GAME: Already submitting, ignoring.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isPreviewMode = false;
    });
    
    debugPrint("GAME: Submitting turn. Text: '$_lastWords', Target: '${currentGame.targetTranslation}'");
    
    try {
      final startTime = DateTime.now();
      debugPrint("GAME: Calling submitTurn...");
      final bool isCorrect = await _gameService.submitTurn(currentGame, _lastWords);
      debugPrint("GAME: submitTurn returned: $isCorrect");
      
      // Ensure the "Analyzing" loader is visible for at least 1.5 seconds for proper UX
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 1500) {
        debugPrint("GAME: Adding UX delay for loader.");
        await Future.delayed(Duration(milliseconds: 1500 - elapsed.inMilliseconds));
      }

      debugPrint("GAME: Updating UI with result.");
      if (mounted) {
        setState(() {
          _lastTurnCorrect = isCorrect;
          _isSubmitting = false;
        });

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() => _lastTurnCorrect = null);
          }
        });
      }
    } catch (e) {
      debugPrint("GAME ERROR: Failed to submit turn: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text("Error"),
            description: Text(e.toString()),
            backgroundColor: Colors.redAccent.shade100,
          ),
        );
      }
    }
    _lastWords = "";
  }

  void _showCancellationSheet() {
    if (_cancellationSheetShown || !mounted) return;
    _cancellationSheetShown = true;
    final l10n = AppLocalizations.of(context)!;

    if (widget.groupId == null && _currentUserId != null) {
      FirebaseFirestore.instance
          .collection('matchmakingPool')
          .doc(_currentUserId)
          .get()
          .then((doc) {
            if (doc.exists && doc.data()?['status'] == 'matched' && doc.data()?['gameSessionId'] == widget.gameId) {
              doc.reference.update({'status': 'waiting'});
            }
          });
    }

    showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) => ShadSheet(
        title: Text(l10n.gameSessionEnded),
        description: Text(l10n.gameSessionEndedDescription),
        actions: [
          ShadButton.outline(
            child: Text(l10n.backToChat),
            onPressed: () {
              Navigator.pop(sheetContext);
              if (widget.onExit != null) {
                widget.onExit!(false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ShadButton(
            child: Text(l10n.findNewMatch),
            onPressed: () {
              Navigator.pop(sheetContext);
              if (widget.onExit != null) {
                widget.onExit!(true);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    ).then((_) => _cancellationSheetShown = false);
  }

  void _initiateCancellation(GameModel game) async {
     final l10n = AppLocalizations.of(context)!;
     final confirm = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width*0.9,),
        removeBorderRadiusWhenTiny: false,
        title: Text(l10n.endGame),
        description: Text(l10n.endGameConfirm),
        actions: [
          ShadButton.outline(child: Text(l10n.keepPlaying), onPressed: () => Navigator.pop(context, false)),
          ShadButton.destructive(child: Text(l10n.cancelGame), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      if (game.groupId != null && game.players.first != _currentUserId) {
        await _gameService.leaveGame(widget.groupId, widget.gameId, _currentUserId!);
        if (widget.onExit != null) widget.onExit!(false);
      } else {
        await _gameService.cancelActiveGame(widget.groupId, widget.gameId);
      }
      
      if (widget.groupId == null && _currentUserId != null) {
        await FirebaseFirestore.instance.collection('matchmakingPool').doc(_currentUserId).update({'status': 'waiting'});
      }
    }
  }

  Widget _buildCelebrationScreen(GameModel game) {
    final l10n = AppLocalizations.of(context)!;
    int highestScore = -1;
    for (var score in game.scores.values) {
      if (score > highestScore) highestScore = score;
    }

    final winners = game.scores.entries
        .where((e) => e.value == highestScore)
        .map((e) => e.key)
        .toList();
    
    final bool amIWinner = winners.contains(_currentUserId);
    final String winnerNames = winners.map((id) => _playerProfiles[id]?.displayName ?? l10n.player).join(", ");

    return Container(
      width: double.infinity,
      color: ShadTheme.of(context).colorScheme.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.trophy, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          Text(amIWinner ? l10n.congratulations : l10n.gameOver, style: ShadTheme.of(context).textTheme.h2.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(winners.length > 1 ? l10n.itsADraw : l10n.winnerAnnounce(winnerNames), style: ShadTheme.of(context).textTheme.h4.copyWith(color: AppTheme.accentColor)),
          const SizedBox(height: 40),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: game.scores.entries.map((entry) {
                  final profile = _playerProfiles[entry.key];
                  final isWinner = winners.contains(entry.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        ShadAvatar(profile?.profilePictureUrl, size: const Size(32, 32)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(profile?.displayName ?? l10n.player, style: TextStyle(fontWeight: isWinner ? FontWeight.bold : FontWeight.normal))),
                        if (isWinner) const Icon(LucideIcons.crown, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(entry.value.toString(), style: ShadTheme.of(context).textTheme.h4.copyWith(fontSize: 18)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: ShadButton.outline(onPressed: () => widget.onExit != null ? widget.onExit!(false) : Navigator.pop(context), child: Text(l10n.backToChat))),
              const SizedBox(width: 12),
              Expanded(child: ShadButton(onPressed: () => widget.onExit != null ? widget.onExit!(true) : Navigator.pop(context), child: Text(l10n.playAgain))),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    debugPrint("GAME BUILD: _isSubmitting=$_isSubmitting, _isPreviewMode=$_isPreviewMode, _lastTurnCorrect=$_lastTurnCorrect");
    return StreamBuilder<GameModel>(
      stream: _gameService.getGameStateStream(widget.groupId,widget.gameId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: ShadTheme.of(context).colorScheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                  const SizedBox(height: 24),
                  Text(l10n.loading.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 10)),
                  const SizedBox(height: 48),
                  ShadButton.outline(
                    onPressed: () {
                      if (widget.onExit != null) widget.onExit!(false);
                    },
                    child: Text(l10n.cancel.toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) return Center(child: Text(l10n.errorLoadingGameState));

        final game = snapshot.data!;
        if (game.status == GameStatus.finished) return _buildCelebrationScreen(game);
        if (game.status == GameStatus.cancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showCancellationSheet());
          return Center(child: Text(l10n.gameCancelled));
        }
        
        if (game.currentPrompt.isEmpty) {
          // If we are the host, trigger initialization. 
          if (game.players.isNotEmpty && game.players.first == _currentUserId) {
             _gameService.initializeMatchmadeGame(game);
          }
          
          return Scaffold(
            backgroundColor: ShadTheme.of(context).colorScheme.background,
            body: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accentColor),
                const SizedBox(height: 32),
                Text(l10n.initializingContent.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ShadButton.outline(
                    width: double.infinity,
                    onPressed: () {
                      _initiateCancellation(game);
                    },
                    child: Text(l10n.cancel.toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (game.players.isNotEmpty && game.players.first == _currentUserId) ...[
                   const SizedBox(height: 16),
                   ShadButton.ghost(
                     onPressed: () => _gameService.initializeMatchmadeGame(game),
                     child: Text(l10n.retryInitialization, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                   ),
                ] else if (game.players.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   Text(l10n.waitingForHost, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ],
            )),
          );
        }

        final isMyTurn = game.currentPlayerId == _currentUserId;
        _loadPlayerProfiles(game.players);

        return Scaffold(
          backgroundColor: ShadTheme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => _initiateCancellation(game),
            ),
            title: Text(
              l10n.questionCountIndicator(game.questionCount).toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 24),
                  onPressed: () => _initiateCancellation(game),
                ),
              ),
              if (game.turnStartTime != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _secondsRemaining < 10 ? Colors.red.withValues(alpha: 0.1) : AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _secondsRemaining < 10 ? Colors.red.withValues(alpha: 0.2) : AppTheme.accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _formatDuration(_secondsRemaining),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                          color: _secondsRemaining < 10 ? Colors.red : AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: game.questionCount / 10,
                        minHeight: 4,
                        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ShadTheme.of(context).colorScheme.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: game.scores.entries.map((entry) {
                          final profile = _playerProfiles[entry.key];
                          final isCurrent = game.currentPlayerId == entry.key;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isCurrent ? AppTheme.accentColor : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: ShadAvatar(profile?.profilePictureUrl, size: const Size(44, 44)),
                                  ),
                                  if (isCurrent)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: AppTheme.accentColor, shape: BoxShape.circle),
                                        child: const Icon(Icons.bolt, size: 12, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile?.displayName.split(' ').first ?? "...",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? AppTheme.accentColor : Colors.grey,
                                ),
                              ),
                              Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isCurrent ? AppTheme.accentColor : null,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (game.turnStartTime == null) ...[
                              const Icon(LucideIcons.hourglass, size: 64, color: Colors.grey),
                              const SizedBox(height: 24),
                              Text(
                                isMyTurn ? l10n.yourTurn : l10n.waitingForPlayer(game.players.indexOf(game.currentPlayerId) + 1),
                                style: ShadTheme.of(context).textTheme.h3.copyWith(fontWeight: FontWeight.w900),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isMyTurn 
                                    ? l10n.holdToStartTurn
                                    : l10n.waitingForDuration(_formatDuration(_waitingSecondsElapsed)),
                                  style: const TextStyle(
                                    color: Colors.grey, 
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [ui.FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              if (isMyTurn)
                                _buildStartTurnButton(game)
                              else
                                const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                            ] else ...[
                              Text(
                                l10n.translateToLanguage(widget.group.currentLanguage).toUpperCase(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentColor, letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                game.currentPrompt,
                                style: ShadTheme.of(context).textTheme.h2.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),
                              
                              if (isMyTurn)
                                _isPreviewMode 
                                  ? _buildPreviewArea(game)
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isListening && _lastWords.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '"$_lastWords"',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.accentColor,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        _buildRecordingButton(game),
                                      ],
                                    )
                              else
                                _buildWaitingForOpponentUI(game),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
              if (_isSubmitting || _lastTurnCorrect != null)
                _buildOverlay(l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartTurnButton(GameModel game) {
    return ShadButton(
      size: ShadButtonSize.lg,
      onPressed: () {
        if (game.turnStartTime == null) {
          _gameService.startTurn(widget.groupId, widget.gameId);
        }
      },
      child: const Text("START TURN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildRecordingButton(GameModel game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => !_isSubmitting ? _startListening(game) : null,
          onTapUp: (_) => _isListening ? _stopListening() : null,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                padding: EdgeInsets.all(20 * _animationController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent.withValues(alpha: 0.2) : AppTheme.accentColor.withValues(alpha: 0.1),
                ),
                child: child,
              );
            },
            child: CircleAvatar(
              radius: 60,
              backgroundColor: _isListening ? Colors.redAccent : AppTheme.accentColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mic, size: 48, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    _isListening ? AppLocalizations.of(context)!.listening.toUpperCase() : "HOLD",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _isListening 
              ? "Keep holding until your transcribed words appear above, then release."
              : "Press & hold mic to speak until transcribed words appear before releasing for AI evaluation.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isListening ? Colors.redAccent : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingForOpponentUI(GameModel game) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accentColor),
        const SizedBox(height: 24),
        Text(
          l10n.opponentTranslating,
          style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(GameModel game) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ShadTheme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reviewPronunciation.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    '"$_lastWords"', 
                    style: ShadTheme.of(context).textTheme.h4.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.accentColor,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: LucideIcons.rotateCcw,
              color: Colors.orange,
              label: "RETRY",
              onTap: () => setState(() {
                _isPreviewMode = false;
                _lastWords = "";
              }),
            ),
            GestureDetector(
              onTap: _playRecording,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.accentColor,
                      child: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play, size: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("PLAY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentColor)),
                ],
              ),
            ),
            _buildActionItem(
              icon: LucideIcons.send,
              color: Colors.green,
              label: "SEND",
              onTap: () => _submitPreview(game),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildOverlay(AppLocalizations l10n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85), // Solid dark background for visibility
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSubmitting) ...[
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(strokeWidth: 4, color: AppTheme.accentColor),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.analyzing.toUpperCase(), 
                style: const TextStyle(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 2.0, 
                  fontSize: 20,
                  color: Colors.white, // Force white text on dark background
                )
              ),
            ] else ...[
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Icon(
                  _lastTurnCorrect! ? LucideIcons.checkCircle : LucideIcons.circleX,
                  color: _lastTurnCorrect! ? Colors.green : Colors.red,
                  size: 100,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _lastTurnCorrect! ? l10n.correct : l10n.incorrect, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 32,
                  fontWeight: FontWeight.w900
                )
              ),
              const SizedBox(height: 12),
              if (_lastTurnCorrect!)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(l10n.pointsAdded, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
