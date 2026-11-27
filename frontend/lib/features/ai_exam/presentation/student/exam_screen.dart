import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/ai_exam_api.dart';
import '../../data/speech_input.dart';
import '../widgets/ai_widgets.dart';

/// Distraction-free test attempt. Answers autosave to the server; reopening resumes.
class ExamScreen extends StatefulWidget {
  final AiExamApi api;
  final String testId;
  const ExamScreen({super.key, required this.api, required this.testId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _Answer {
  final TextEditingController text;
  int? choice;
  bool typed = false;
  bool voice = false;
  int version = 0;
  _Answer(String t, this.choice, String method) : text = TextEditingController(text: t) {
    typed = method == 'TYPED' && t.isNotEmpty || method == 'MIXED';
    voice = method == 'VOICE' || method == 'MIXED';
  }
  String get method => voice && typed ? 'MIXED' : (voice ? 'VOICE' : 'TYPED');
  bool get answered => choice != null || text.text.trim().isNotEmpty;
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _loadError;
  List<Map<String, dynamic>> _questions = [];
  final Map<String, _Answer> _answers = {};
  final Map<String, int> _dirty = {}; // questionId -> version to save
  int _index = 0;

  // timing (server clock)
  Duration _skew = Duration.zero;
  DateTime? _deadline;
  Duration? _left;
  Timer? _clock;

  // saving
  Timer? _debounce;
  Timer? _retry;
  bool _saving = false;
  String? _saveError;
  DateTime? _savedAt;
  bool _submitting = false;
  bool _submitted = false;

  // voice
  late final SpeechInput _speech = speechInputFactory();
  bool? _voiceReady;
  String? _listeningFor;
  String _partial = '';
  String? _voiceMessage;
  bool _allowVoice = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    if (_listeningFor != null) _speech.cancel();
    // Best effort on the way out (no setState after dispose).
    if (_dirty.isNotEmpty && !_submitted) widget.api.saveAnswers(widget.testId, _payload(_dirty.keys)).catchError((_) => <String, dynamic>{});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_listeningFor != null) _stopVoice();
      _save();
    }
  }

  Future<void> _start() async {
    setState(() => _loadError = null);
    try {
      final d = await widget.api.start(widget.testId);
      if (!mounted) return;
      final server = DateTime.tryParse('${d['serverTime']}');
      _skew = server == null ? Duration.zero : server.difference(DateTime.now());
      _deadline = DateTime.tryParse('${d['deadline']}');
      _questions = AiExamApi.list(d['questions']);
      final saved = {for (final a in AiExamApi.list(d['answers'])) a['questionId'] as String: a};
      for (final q in _questions) {
        final a = saved[q['id']];
        _answers[q['id'] as String] = _Answer('${a?['text'] ?? ''}', a?['choice'] as int?, '${a?['inputMethod'] ?? 'TYPED'}');
      }
      _allowVoice = d['allowVoice'] != false;
      final firstOpen = _questions.indexWhere((q) => !_answers[q['id']]!.answered);
      setState(() {
        _data = d;
        _index = firstOpen < 0 ? 0 : firstOpen;
        _savedAt = saved.isEmpty ? null : DateTime.now();
      });
      _tick();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e) {
      if (mounted) setState(() => _loadError = apiErrorMessage(e));
    }
  }

  void _tick() {
    if (_deadline == null || _submitted) return;
    final left = _deadline!.difference(DateTime.now().add(_skew));
    if (!mounted) return;
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left <= Duration.zero && !_submitting) {
      _clock?.cancel();
      _submit(auto: true);
    }
  }

  // ------------------------------------------------------------------ saving

  void _changed(String questionId, {bool typed = false, bool voice = false}) {
    final a = _answers[questionId]!;
    if (typed) a.typed = true;
    if (voice) a.voice = true;
    a.version++;
    _dirty[questionId] = a.version;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _save);
    setState(() {});
  }

  List<Map<String, dynamic>> _payload(Iterable<String> ids) => [
        for (final id in ids)
          {'questionId': id, 'text': _answers[id]!.text.text, 'choice': _answers[id]!.choice, 'inputMethod': _answers[id]!.method},
      ];

  Future<void> _save() async {
    if (!mounted || _saving || _dirty.isEmpty || _submitted) return;
    final batch = Map<String, int>.from(_dirty);
    setState(() => _saving = true);
    try {
      await widget.api.saveAnswers(widget.testId, _payload(batch.keys));
      // Keep anything edited while the request was in flight.
      batch.forEach((id, v) {
        if (_dirty[id] == v) _dirty.remove(id);
      });
      _retry?.cancel();
      if (mounted) {
        setState(() {
          _saveError = null;
          _savedAt = DateTime.now();
        });
      }
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (mounted) {
        setState(() => _saveError = status == 403 || status == 409 ? apiErrorMessage(e) : 'Not saved yet - retrying (check your connection)');
      }
      if (status != 403 && status != 409) {
        _retry?.cancel();
        _retry = Timer(const Duration(seconds: 5), _save);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      if (_dirty.isNotEmpty && _saveError == null && mounted) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 600), _save);
      }
    }
  }

  // ------------------------------------------------------------------ submit

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _submitted) return;
    if (!auto) {
      final unanswered = _questions.where((q) => !_answers[q['id']]!.answered).length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit test?'),
          content: Text(unanswered > 0 ? '$unanswered question(s) are unanswered. You cannot change answers after submitting.' : 'All questions are answered. You cannot change answers after submitting.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep working')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (_listeningFor != null) await _stopVoice();
    setState(() => _submitting = true);
    _debounce?.cancel();
    _retry?.cancel();
    try {
      await widget.api.submit(widget.testId, _payload(_answers.keys));
      _done(auto ? 'Time is up. Your answers were submitted.' : 'Your answers were submitted.');
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status == 409) {
        _done('This test was already submitted.');
        return;
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _saveError = apiErrorMessage(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: ${apiErrorMessage(e)}. Your answers are saved; try again.')));
        if (auto) Timer(const Duration(seconds: 5), () => _submit(auto: true));
      }
    }
  }

  void _done(String message) {
    _submitted = true;
    _dirty.clear();
    _clock?.cancel();
    if (!mounted) return;
    setState(() => _submitting = false);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.task_alt, color: AppColors.success, size: 40),
        title: const Text('Submitted'),
        content: Text('$message Your teacher will publish the result after evaluation.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ voice

  Future<void> _toggleVoice(String questionId) async {
    if (_listeningFor != null) return _stopVoice();
    _voiceReady ??= await _speech.init();
    if (!mounted) return;
    if (_voiceReady != true) {
      setState(() => _voiceMessage = 'Voice input is not available on this device or microphone access was denied. Please type your answer.');
      return;
    }
    setState(() {
      _listeningFor = questionId;
      _partial = '';
      _voiceMessage = null;
    });
    try {
      await _speech.start(
        onText: (text, isFinal) {
          if (!mounted || _listeningFor != questionId) return;
          if (isFinal) {
            _commitVoice(questionId, text);
          } else {
            setState(() => _partial = text);
          }
        },
        onError: (msg) {
          if (!mounted) return;
          // Keep whatever was heard so far; nothing is discarded.
          if (_partial.isNotEmpty) _commitVoice(questionId, _partial);
          setState(() {
            _listeningFor = null;
            _voiceMessage = msg;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listeningFor = null;
          _voiceMessage = 'Could not start the microphone. Please type your answer.';
        });
      }
    }
  }

  void _commitVoice(String questionId, String text) {
    final a = _answers[questionId]!;
    a.text.text = appendTranscript(a.text.text, text);
    a.text.selection = TextSelection.collapsed(offset: a.text.text.length);
    setState(() {
      _partial = '';
      _listeningFor = null;
    });
    _changed(questionId, voice: true);
  }

  Future<void> _stopVoice() async {
    final id = _listeningFor;
    await _speech.stop();
    if (id != null && _partial.isNotEmpty) {
      _commitVoice(id, _partial);
    } else if (mounted) {
      setState(() => _listeningFor = null);
    }
  }

  // ------------------------------------------------------------------ UI

  void _go(int i) {
    if (i < 0 || i >= _questions.length) return;
    if (_listeningFor != null) _stopVoice();
    _save();
    setState(() => _index = i);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Future<void> _openNavigator() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_answers.values.where((a) => a.answered).length} of ${_questions.length} answered', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (i, q) in _questions.indexed) _numberChip(i, q, () => Navigator.pop(ctx, i)),
            ]),
          ]),
        ),
      ),
    );
    if (picked != null) _go(picked);
  }

  Widget _numberChip(int i, Map<String, dynamic> q, VoidCallback onTap) {
    final answered = _answers[q['id']]!.answered;
    final current = i == _index;
    return Semantics(
      button: true,
      label: 'Question ${i + 1}, ${answered ? 'answered' : 'not answered'}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: answered ? AppColors.primaryAccent : AppColors.surface,
            border: Border.all(color: current ? AppColors.primaryNavy : (answered ? AppColors.primaryAccent : AppColors.borderStrong), width: current ? 2.5 : 1),
          ),
          child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: answered ? Colors.white : AppColors.textDark)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [MessageBanner(message: _loadError!, onRetry: _start)]),
      );
    }
    if (_data == null) return const Scaffold(body: LoadingStateView(message: 'Opening your test...'));
    final test = AiExamApi.map(_data!['test']);
    final answered = _answers.values.where((a) => a.answered).length;
    final q = _questions[_index];
    final low = _left != null && _left! < const Duration(minutes: 2);
    return PopScope(
      canPop: _submitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (!context.mounted) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave the test?'),
            content: Text('Your answers are saved${_dirty.isEmpty ? '' : ' (some changes are still saving)'}. ${_deadline != null ? 'The timer keeps running.' : ''} You can resume before the test closes.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${test['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('${test['subject']} · ${fmtNum(test['totalMarks'] as num?)} marks', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          actions: [
            if (_left != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Semantics(
                  label: 'Time left ${_fmt(_left!)}',
                  child: Pill(label: _fmt(_left!), color: low ? AppColors.error : AppColors.primaryAccent, icon: Icons.timer_outlined),
                ),
              ),
            IconButton(tooltip: 'All questions', icon: const Icon(Icons.grid_view_rounded), onPressed: _openNavigator),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            LinearProgressIndicator(value: _questions.isEmpty ? 0 : answered / _questions.length, minHeight: 4, backgroundColor: AppColors.surfaceMuted),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
                itemCount: _questions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _numberChip(i, _questions[i], () => _go(i)),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _questionView(q)),
            _bottomBar(answered),
          ]),
        ),
      ),
    );
  }

  Widget _questionView(Map<String, dynamic> q) {
    final text = Theme.of(context).textTheme;
    final id = q['id'] as String;
    final a = _answers[id]!;
    final type = '${q['type']}';
    final options = q['options'] as List?;
    final listening = _listeningFor == id;
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      Row(children: [
        Text('Question ${_index + 1} of ${_questions.length}', style: text.labelLarge?.copyWith(color: AppColors.textMuted)),
        const Spacer(),
        Pill(label: '${fmtNum(q['marks'] as num?)} mark${q['marks'] == 1 ? '' : 's'}', color: AppColors.primaryAccent),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text('${q['text']}', style: text.titleMedium?.copyWith(height: 1.4)),
      if (q['imageUrl'] != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(widget.api.imageUrl('${q['imageUrl']}'), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Text('Image could not be loaded')),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      if (options != null)
        RadioGroup<int>(
          groupValue: a.choice,
          onChanged: (v) {
            a.choice = v;
            _changed(id);
          },
          child: Column(children: [
            for (final (j, o) in options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: a.choice == j ? AppColors.primaryAccentSubtle : AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: a.choice == j ? AppColors.primaryAccent : AppColors.border)),
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<int>(value: j, title: Text(type == 'TRUE_FALSE' ? '$o' : '${String.fromCharCode(65 + j)}. $o')),
                ),
              ),
          ]),
        )
      else ...[
        TextField(
          controller: a.text,
          minLines: type == 'LONG' ? 8 : (type == 'SHORT' || type == 'NUMERICAL' ? 4 : 1),
          maxLines: type == 'FILL_BLANK' ? 2 : null,
          maxLength: 20000,
          keyboardType: type == 'NUMERICAL' ? TextInputType.multiline : TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: switch (type) {
              'FILL_BLANK' => 'Your answer',
              'NUMERICAL' => 'Show your working and write the final answer with its unit',
              _ => 'Type your answer, or tap the microphone to speak',
            },
            alignLabelWithHint: true,
            counterText: '${a.text.text.length} characters',
          ),
          onChanged: (_) => _changed(id, typed: true),
        ),
        if (_allowVoice)
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.tonalIcon(
              onPressed: _submitting ? null : () => _toggleVoice(id),
              icon: Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none),
              label: Text(listening ? 'Stop' : 'Speak answer'),
              style: listening ? FilledButton.styleFrom(backgroundColor: AppColors.errorBg, foregroundColor: AppColors.error) : null,
            ),
            if (a.voice) const Pill(label: 'includes voice', color: AppColors.info, icon: Icons.record_voice_over_outlined),
          ]),
        if (listening)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.graphic_eq, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(_partial.isEmpty ? 'Listening… speak now' : _partial, style: text.bodyMedium)),
            ]),
          ),
        if (_voiceMessage != null)
          Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: MessageBanner(message: _voiceMessage!, isError: false, onDismiss: () => setState(() => _voiceMessage = null))),
      ],
    ]);
  }

  Widget _bottomBar(int answered) {
    final text = Theme.of(context).textTheme;
    final last = _index == _questions.length - 1;
    final status = _saveError ?? (_saving ? 'Saving…' : (_dirty.isNotEmpty ? 'Unsaved changes' : (_savedAt != null ? 'All answers saved' : '$answered of ${_questions.length} answered')));
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(_saveError != null ? Icons.cloud_off : (_dirty.isEmpty && !_saving ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined), size: 16, color: _saveError != null ? AppColors.error : AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: _saveError != null ? AppColors.error : AppColors.textMuted))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            IconButton.outlined(tooltip: 'Previous question', onPressed: _index == 0 ? null : () => _go(_index - 1), icon: const Icon(Icons.chevron_left)),
            const SizedBox(width: AppSpacing.sm),
            if (!last)
              Expanded(
                child: FilledButton.tonalIcon(onPressed: () => _go(_index + 1), icon: const Icon(Icons.chevron_right), label: const Text('Next')),
              ),
            if (!last && answered == _questions.length) const SizedBox(width: AppSpacing.sm),
            if (last || answered == _questions.length)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : () => _submit(),
                  icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                  label: const Text('Submit'),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
