import 'package:flutter/material.dart';
import '../core/astro.dart';
import '../core/theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0, score = 0;
  int? sel;

  void choose(int k) {
    if (sel != null) return;
    setState(() { sel = k; if (k == quiz[i].c) score++; });
    Future.delayed(const Duration(milliseconds: 1100), () { if (mounted) setState(() { sel = null; i++; }); });
  }

  @override
  Widget build(BuildContext context) {
    if (i >= quiz.length) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${fa(score)}/${fa(quiz.length)}', style: const TextStyle(fontSize: 64, color: C.gold, fontWeight: FontWeight.bold)),
        Text(score >= 4 ? 'منجم واقعی!' : score >= 2 ? 'خوب بود، یه کم دیگه رصد کن' : 'آسمان منتظرته', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night), onPressed: () => setState(() { i = 0; score = 0; }), child: const Text('دوباره')),
      ]));
    }
    final q = quiz[i];
    return ListView(padding: const EdgeInsets.all(24), children: [
      LinearProgressIndicator(value: i / quiz.length, color: C.brass, backgroundColor: C.plate),
      const SizedBox(height: 24),
      Text('سؤال ${fa(i + 1)} از ${fa(quiz.length)}', style: const TextStyle(color: C.muted)),
      Text(q.q, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 20),
      for (var k = 0; k < q.a.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(18),
              alignment: Alignment.centerRight,
              backgroundColor: sel == null ? C.plate : k == q.c ? C.teal : k == sel ? C.red : C.plate,
              foregroundColor: C.text,
            ),
            onPressed: () => choose(k),
            child: Text(q.a[k], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ),
    ]);
  }
}
