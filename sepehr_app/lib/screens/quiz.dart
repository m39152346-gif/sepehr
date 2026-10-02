import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/astro.dart';
import '../core/theme.dart';

const _bestScoreKey = 'quiz_best_score_v2';

/// A fresh randomized quiz round with immediate explanations and saved best score.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuizQ> _questions;
  int _index = 0;
  int _score = 0;
  int _bestScore = 0;
  int? _selected;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _questions = quiz.toList()..shuffle(Random());
    SharedPreferences.getInstance().then((preferences) {
      if (mounted) setState(() => _bestScore = preferences.getInt(_bestScoreKey) ?? 0);
    }).catchError((_) {});
  }

  void _choose(int answerIndex) {
    if (_selected != null || _index >= _questions.length) return;
    final isCorrect = answerIndex == _questions[_index].correctIndex;
    setState(() {
      _selected = answerIndex;
      if (isCorrect) _score++;
    });
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1500), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      setState(() {
        _index = _questions.length;
        _selected = null;
      });
      _saveBest();
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  Future<void> _saveBest() async {
    if (_score <= _bestScore) return;
    setState(() => _bestScore = _score);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_bestScoreKey, _score);
    } catch (_) {
      // The score remains visible for this session even if persistence fails.
    }
  }

  void _newRound() {
    _advanceTimer?.cancel();
    setState(() {
      _questions = quiz.toList()..shuffle(Random());
      _index = 0;
      _score = 0;
      _selected = null;
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _questions.length) return _result();
    final question = _questions[_index];
    final answered = _selected != null;
    final isCorrect = answered && _selected == question.correctIndex;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        Row(
          children: [
            const Expanded(child: Text('چالش نجوم', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('بهترین ${fa(_bestScore)}/${fa(quiz.length)}', style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
                Text('امتیاز ${fa(_score)}', style: const TextStyle(color: C.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_index + (answered ? 1 : 0)) / _questions.length,
            minHeight: 8,
            color: C.brass,
            backgroundColor: C.plateLight,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Chip(label: Text(question.category), backgroundColor: C.plate, side: BorderSide.none),
            const Spacer(),
            Text('سؤال ${fa(_index + 1)} از ${fa(_questions.length)}', style: const TextStyle(color: C.muted)),
          ],
        ),
        const SizedBox(height: 8),
        Text(question.question, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.4)),
        const SizedBox(height: 20),
        for (var index = 0; index < question.answers.length; index++) _answerButton(question, index),
        if (answered) ...[
          const SizedBox(height: 8),
          Card(
            color: isCorrect ? const Color(0xFF143C3A) : const Color(0xFF3A2633),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isCorrect ? Icons.check_circle : Icons.info_outline, color: isCorrect ? C.good : C.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(question.explanation, style: const TextStyle(height: 1.5))),
                ],
              ),
            ),
          ),
          const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('سؤال بعدی…', style: TextStyle(color: C.muted, fontSize: 12)))),
        ],
      ],
    );
  }

  Widget _answerButton(QuizQ question, int index) {
    final selected = _selected;
    final correct = index == question.correctIndex;
    final color = selected == null
        ? C.plate
        : correct
            ? const Color(0xFF176451)
            : selected == index
                ? const Color(0xFF793B47)
                : C.plate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          alignment: Alignment.centerRight,
          backgroundColor: color,
          foregroundColor: C.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: selected == null ? () => _choose(index) : null,
        child: Row(
          children: [
            Expanded(child: Text(question.answers[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            if (selected != null && correct) const Icon(Icons.check_circle, color: C.good),
            if (selected == index && !correct) const Icon(Icons.cancel, color: C.red),
          ],
        ),
      ),
    );
  }

  Widget _result() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, color: C.gold, size: 66),
              const SizedBox(height: 8),
              Text('${fa(_score)} / ${fa(_questions.length)}',
                  style: const TextStyle(fontSize: 54, color: C.gold, fontWeight: FontWeight.w900)),
              Text(_score >= 10 ? 'درخشان بود!' : _score >= 7 ? 'آفرین، رصدگر!' : _score >= 4 ? 'خوب بود؛ ادامه بده.' : 'هر پاسخ، یک کشف تازه است.',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('بهترین رکورد: ${fa(_bestScore)} از ${fa(quiz.length)}', style: const TextStyle(color: C.muted)),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                onPressed: _newRound,
                icon: const Icon(Icons.replay),
                label: const Text('دور تازه با سؤال‌های تصادفی'),
              ),
            ],
          ),
        ),
      );
}
