import 'dart:async';
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
import 'package:lingua_leap/models/language_strength.dart';

class GameView extends StatefulWidget {
  final String gameId;
  final String? groupId;
  final GroupModel group;

  const GameView({
    super.key,
    required this.gameId,
    this.groupId,
    required this.group,
  });

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final UserService _userService = UserService();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastWords = "";
  bool _speechEnabled = false;
  bool? _lastTurnCorrect;
  bool _isSubmitting = false;
  LanguageStrength userStrength = LanguageStrength.beginner;
  late AnimationController _animationController;
  Map<String, UserModel> _playerProfiles = {};


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
    // Check if we already have all profiles
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Initializes the speech-to-text engine
  void _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() {
              _isListening = false;
              _animationController.stop();
              _animationController.reset();
            });
          }
        },
      );
      if (mounted) setState(() {});
    } else if (status.isPermanentlyDenied) {
      // If permission is permanently denied, show a dialog to open settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ShadDialog(
            closeIcon: ShadIconButton.ghost(icon: const Icon(LucideIcons.x,size: 0,),enabled: false,),
            removeBorderRadiusWhenTiny: false,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            title: const Text("Microphone Permission"),
            description: const Text(
              "Microphone permission is required to play the voice game. "
                  "Please enable it in your device settings.",
            ),
            actions: [
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  ShadButton.ghost(
                    onPressed: () {
                      //Navigate back
                       Navigator.pop(context);
                       Navigator.pop(context);
                      },
                    child: const Text("Cancel"),
                  ),
                  ShadButton(
                    onPressed: () => openAppSettings(),
                    child: const Text("Open Settings"),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } else {
     mounted ? ShadToaster.of(context).show(
        ShadToast(
          title: const Text("Microphone Permission"),
          description: const Text("Microphone permission is required to play the voice game."),
          backgroundColor: Colors.redAccent.shade100,
        ),
      ):const SizedBox();
    }
  }

  /// Starts listening to the user's voice
  void _startListening() async {
    // Check if speech is enabled AND not already listening before starting.
    if (_speechEnabled && !_speechToText.isListening) {
      await _speechToText.listen(onResult: (result) {
        _onSpeechResult(result);
      });
      if (mounted) {
        setState(() => _isListening = true);
        _animationController.repeat(reverse: true);
      }
    } else {
      // Handle the case where speech not available or already listening
      // Optionally, show a message to the user
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text("Speech not enabled or already listening."),
            description: Text(_speechEnabled 
                ? "Microphone already active." 
                : "Speech recognition initialization failed or was not allowed."),
            backgroundColor: Colors.redAccent.shade100,
          ),
        );
      }
    }
  }

  /// Stops listening and processes the result
  void _stopListening(GameModel currentGame) async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _animationController.stop();
        _animationController.reset();
      });
    }

    // After stopping, submit final words to the game service
    if (_lastWords.isNotEmpty) {
      setState(() => _isSubmitting = true);
      
      final bool isCorrect = await _gameService.submitTurn(currentGame, _lastWords);
      
      if (mounted) {
        setState(() {
          _lastTurnCorrect = isCorrect;
          _isSubmitting = false;
        });

        // Show feedback for 2.5 seconds then reset result UI
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() => _lastTurnCorrect = null);
          }
        });
      }
      _lastWords = ""; // Reset last words for next turn
    }
  }

  /// Called continuously as the user speaks
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_isSubmitting) return; // Don't update while processing
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameModel>(
      stream: _gameService.getGameStateStream(widget.groupId,widget.gameId),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor,));
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading game state."));
        }

        final game = snapshot.data!;
        
        // Auto-initialize if it's a new matchmade game with no prompts yet
        if (game.groupId == null && game.currentPrompt.isEmpty && game.players.first == _currentUserId) {
          _gameService.initializeMatchmadeGame(game);
          return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
              SizedBox(height: 16),
              Text("Initializing game content..."),
            ],
          ));
        }

        final isMyTurn = game.currentPlayerId == _currentUserId;
        _loadPlayerProfiles(game.players);

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Scoreboard
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: game.scores.entries.map((entry) {
                          final profile = _playerProfiles[entry.key];
                          final isCurrent = game.currentPlayerId == entry.key;
    
                          return Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCurrent ? Colors.green : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ShadAvatar(profile?.profilePictureUrl, size: const Size(40, 40)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.displayName.split(' ').first ?? "...",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? Colors.green : null,
                                  ),
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: ShadTheme.of(context).textTheme.h4.copyWith(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Game prompt
                  Center(
                    child: Text(
                      isMyTurn
                          ? "Your Turn!"
                          : "Waiting for Player ${game.players.indexOf(game.currentPlayerId) + 1}...",
                      style: ShadTheme.of(context).textTheme.h4.copyWith(
                        color: isMyTurn ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Translate to ${widget.group.currentLanguage}:',
                    style: ShadTheme.of(context).textTheme.p,
                  ),
                  Center(
                    child: Text(
                      game.currentPrompt,
                      style: ShadTheme.of(context).textTheme.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Record button
                  if (isMyTurn)
                    GestureDetector(
                      onTapDown: (_) {
                        if (!_isSubmitting) _startListening();
                      },
                      onTapUp: (_) {
                        if (_isListening) _stopListening(game);
                      },
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Container(
                            padding: EdgeInsets.all(12 * _animationController.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening 
                                  ? Colors.redAccent.withValues(alpha: 0.2) 
                                  : Colors.transparent,
                            ),
                            child: child,
                          );
                        },
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: _isListening ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.mic, size: 50, color: Colors.white),
                              if (_isListening)
                                const Text("Listening...", style: TextStyle(color: Colors.white))
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor,),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            
            // Results/Submitting Overlay
            if (_isSubmitting || _lastTurnCorrect != null)
              Container(
                color: Colors.black.withValues(alpha: 0.8),
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting) ...[
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 20),
                        const Text("Analyzing...", style: TextStyle(color: Colors.white, fontSize: 20)),
                      ] else ...[
                        Icon(
                          _lastTurnCorrect! ? Icons.check_circle : Icons.cancel,
                          color: _lastTurnCorrect! ? Colors.green : Colors.red,
                          size: 100,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _lastTurnCorrect! ? "CORRECT!" : "INCORRECT",
                          style: TextStyle(
                            color: _lastTurnCorrect! ? Colors.green : Colors.red,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "+10 Points",
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
