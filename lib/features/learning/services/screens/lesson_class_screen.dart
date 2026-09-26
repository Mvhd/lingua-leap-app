import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lingua_leap/features/auth/services/user_service.dart';
import 'package:lingua_leap/features/learning/services/learning_service.dart';
import 'package:lingua_leap/features/learning/services/screens/quiz_screen.dart';
import 'package:lingua_leap/models/lesson_model.dart';
import 'package:lingua_leap/models/question_model.dart';
import 'package:lingua_leap/models/topic_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../../app/theme/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/language_strength.dart';
import '../../../../models/user_model.dart';
import '../../../../services/tts_service.dart';
import '../../../../services/language_service.dart';

class LessonClassScreen extends StatefulWidget {
  final String topicId;
  final LessonModel lesson;
  final TopicModel topic;

  const LessonClassScreen({
    super.key,
    required this.topicId,
    required this.lesson,
    required this.topic,
  });

  @override
  State<LessonClassScreen> createState() => _LessonClassScreenState();
}

class _LessonClassScreenState extends State<LessonClassScreen> with SingleTickerProviderStateMixin {
  final LearningService _learningService = LearningService();
  final UserService _userService = UserService();
  final LanguageService _languageService = LanguageService();
  late final TextToSpeechService _ttsService = TextToSpeechService(languageService: _languageService);

  late Future<List<QuestionModel>> _studyMaterialFuture;
  late AnimationController _pulseController;
  int _currentIndex = 0;
  bool _showTranslation = false;
  UserModel? _currentUser;
  List<QuestionModel>? _studyItems;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.3,
    );
    _studyMaterialFuture = _fetchStudyMaterial();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<List<QuestionModel>> _fetchStudyMaterial() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final user = await _userService.getUserProfile(uid);
        if (mounted) setState(() => _currentUser = user);
      }
      
      final strength = _currentUser?.languageStrength ?? LanguageStrength.beginner;
      final questions = await _learningService.getQuizQuestions(widget.topicId, widget.lesson.id, strength);
      
      // Randomize and limit to 10
      questions.shuffle(Random());
      final limitedQuestions = questions.take(10).toList();

      for (int i = 0; i < limitedQuestions.length; i++) {
        final q = limitedQuestions[i];
        final nativeWordInQuotes = _extractQuotedText(q.questionText);
        
        limitedQuestions[i] = QuestionModel(
          id: q.id,
          questionText: nativeWordInQuotes, // Holds NATIVE word extracted from question
          originalQuestionText: q.questionText,
          options: q.options,
          correctAnswer: q.correctAnswer, // Holds TARGET word
          transliterateCorrectAnswer: q.transliterateCorrectAnswer, // Carry over transliteration
          strength: q.strength,
        );
      }
      
      _studyItems = limitedQuestions;
      return limitedQuestions;
    } catch (e) {
      debugPrint("CLASS ERROR: $e");
      rethrow;
    }
  }

  void _speak(String text) async {
    _pulseController.forward().then((_) => _pulseController.reverse());
    await _ttsService.speak(text, widget.lesson.language);
  }

  void _next() {
    if (_studyItems == null) return;
    if (_currentIndex < _studyItems!.length - 1) {
      setState(() {
        _currentIndex++;
        _showTranslation = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showTranslation = false;
      });
    }
  }

  String _extractQuotedText(String text) {
    final regex = RegExp(r'''([""])(.*?)\1''');
    final match = regex.firstMatch(text);
    return match?.group(2) ?? text;
  }

  void _showCompletionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        title: Text(l10n.classCompleted),
        removeBorderRadiusWhenTiny: false,
        description: Text(l10n.classCompletedDesc),
        actions: [
          ShadButton.outline(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ShadButton(
            child: Text(l10n.proceedToQuiz.toUpperCase()),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizScreen(
                    topicId: widget.topicId,
                    lesson: widget.lesson,
                    topic: widget.topic,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<QuestionModel>>(
        future: _studyMaterialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noQuestionsYet));
          }

          final items = snapshot.data!;
          final currentItem = items[_currentIndex];
          final progress = (_currentIndex + 1) / items.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.studyMode.toUpperCase(),
                          style: theme.textTheme.muted.copyWith(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                        ),
                        Text(
                          "${_currentIndex + 1} / ${items.length}",
                          style: theme.textTheme.muted.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.muted,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimationLimiter(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 375),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            GestureDetector(
                              onTap: () => _speak(currentItem.correctAnswer),
                              child: ShadCard(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    ScaleTransition(
                                      scale: _pulseController,
                                      child: const Icon(LucideIcons.volume2, size: 48, color: AppTheme.accentColor),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      currentItem.transliterateCorrectAnswer != null
                                          ? "${currentItem.correctAnswer} (${currentItem.transliterateCorrectAnswer})"
                                          : currentItem.correctAnswer, // Display Target Language word on top with transliteration
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.h2.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.tapToListen,
                                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_showTranslation)
                              ShadCard(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                backgroundColor: theme.colorScheme.accent.withValues(alpha: 0.1),
                                child: Center(
                                  child: Text(
                                    currentItem.questionText, // Display Native Language translation here
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.h4.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              )
                            else
                              ShadButton.outline(
                                child: Text(l10n.showTranslation),
                                onPressed: () => setState(() => _showTranslation = true),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        Expanded(
                          child: ShadButton.outline(
                            onPressed: _previous,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(l10n.previousPhrase),
                            ),
                          ),
                        ),
                      if (_currentIndex > 0) const SizedBox(width: 16),
                      Expanded(
                        child: ShadButton(
                          onPressed: _next,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _currentIndex < items.length - 1 ? l10n.nextPhrase : l10n.completeClass,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
