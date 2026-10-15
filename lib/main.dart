import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TranApp());
}

/// 主色调：白色 + 黄色点缀，避免蓝色
const kYellow = Color(0xFFF5B301);
const kYellowDark = Color(0xFFE0A200);
const kYellowLight = Color(0xFFFFF6DF);
const kInk = Color(0xFF23201C);
const kInkSoft = Color(0xFF8A857C);
const kCard = Colors.white;
const kPageBg = Colors.white;

class TranApp extends StatelessWidget {
  const TranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tran',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kYellow,
          primary: kYellow,
          surface: kCard,
        ),
        scaffoldBackgroundColor: kPageBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPageBg,
          surfaceTintColor: kPageBg,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const TranslatePage(),
    );
  }
}

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  final _service = TranslationService();

  Lang _from = kLanguages[0]; // 中文
  Lang _to = kLanguages[1]; // 英语

  bool _loading = false;
  String _result = '';
  String? _error;
  String _provider = '';

  @override
  void initState() {
    super.initState();
    _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final f = prefs.getString('from');
    final t = prefs.getString('to');
    if (!mounted) return;
    setState(() {
      _from = kLanguages.firstWhere((l) => l.code == f, orElse: () => _from);
      _to = kLanguages.firstWhere((l) => l.code == t, orElse: () => _to);
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('from', _from.code);
    await prefs.setString('to', _to.code);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _service.dispose();
    super.dispose();
  }

  /// 互换两边语言；结果已是译文时，直接反向回填，体验更顺
  Future<void> _swap() async {
    setState(() {
      final f = _from;
      _from = _to;
      _to = f;
      _error = null;
      // 若当前有翻译结果，直接把结果当作新一轮输入，实现"反转回译"
      if (_result.isNotEmpty) {
        _inputController.text = _result;
        _result = '';
        _provider = '';
      }
    });
    await _savePrefs();
    if (_inputController.text.trim().isNotEmpty) {
      _translate(); // 互换后自动翻译
    }
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = '';
    });
    try {
      final r = await _service.translate(text: text, from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _result = r.text;
        _provider = r.provider;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    if (_result.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _result));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('已复制到剪贴板'),
          backgroundColor: kInk,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _clear() {
    setState(() {
      _inputController.clear();
      _result = '';
      _error = null;
      _provider = '';
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLangBar(),
                      const SizedBox(height: 16),
                      _buildInputCard(),
                      const SizedBox(height: 14),
                      _buildTranslateButton(),
                      const SizedBox(height: 18),
                      _buildResultCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 头部 ----------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kYellowLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.translate, color: kYellowDark, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'tran',
            style: TextStyle(
              color: kInk,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '${_from.label} → ${_to.label}',
            style: const TextStyle(color: kInkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ---------- 语言选择条 ----------

  Widget _buildLangBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEAE0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _langDropdown(_from, true)),
          _swapButton(),
          Expanded(child: _langDropdown(_to, false)),
        ],
      ),
    );
  }

  Widget _langDropdown(Lang value, bool isSource) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Lang>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kInkSoft),
        dropdownColor: kCard,
        items: [
          for (final l in kLanguages)
            DropdownMenuItem(
              value: l,
              child: Text(
                l.label,
                style: TextStyle(
                  color: l == value ? kYellowDark : kInk,
                  fontWeight: l == value ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ],
        onChanged: (l) {
          if (l == null) return;
          setState(() {
            if (isSource) {
              _from = l;
              if (_to == l) _to = _swapOf(l);
            } else {
              _to = l;
              if (_from == l) _from = _swapOf(l);
            }
            _error = null;
          });
          _savePrefs();
        },
      ),
    );
  }

  Lang _swapOf(Lang l) {
    // 若两边重复，把另一边换成默认候选
    final idx = kLanguages.indexOf(l);
    return kLanguages[(idx + 1) % kLanguages.length];
  }

  Widget _swapButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: kYellow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _swap,
          child: const SizedBox(
            width: 46,
            height: 40,
            child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  // ---------- 输入区 ----------

  Widget _buildInputCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFEAE0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _inputController,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 4,
            maxLength: 2000,
            style: const TextStyle(color: kInk, fontSize: 18, height: 1.5),
            cursorColor: kYellow,
            decoration: const InputDecoration(
              hintText: '输入要翻译的文字…',
              hintStyle: TextStyle(color: Color(0xFFC9C4BA), fontSize: 17),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_inputController.text.length}/2000',
                style: const TextStyle(color: Color(0xFFC9C4BA), fontSize: 12),
              ),
              const SizedBox(width: 6),
              if (_inputController.text.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded, color: kInkSoft, size: 20),
                  tooltip: '清空',
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 翻译按钮 ----------

  Widget _buildTranslateButton() {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: kYellow.withValues(alpha:0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kYellow,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kYellow.withValues(alpha:0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          onPressed: (_loading || _inputController.text.trim().isEmpty)
              ? null
              : _translate,
          child: _loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.6,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 22),
                    SizedBox(width: 8),
                    Text('翻译'),
                  ],
                ),
        ),
      ),
    );
  }

  // ---------- 结果区 ----------

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
      decoration: BoxDecoration(
        color: _hasContent ? kYellowLight : kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _hasContent ? kYellow.withValues(alpha:0.45) : const Color(0xFFEFEAE0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _to.label,
                style: const TextStyle(
                  color: kYellowDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_result.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_rounded, size: 20, color: kInk),
                      tooltip: '复制',
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _swap,
                      icon: const Icon(
                        Icons.swap_vert_rounded,
                        size: 20,
                        color: kInk,
                      ),
                      tooltip: '反转回译',
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (_loading)
            _loadingHint()
          else if (_error != null)
            _errorView()
          else if (_result.isNotEmpty)
            SelectableText(
              _result,
              style: const TextStyle(
                color: kInk,
                fontSize: 20,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            const Text(
              '翻译结果会显示在这里',
              style: TextStyle(color: Color(0xFFC9C4BA), fontSize: 16),
            ),
          if (_provider.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _provider == 'google' ? 'via Google' : 'via MyMemory',
              style: TextStyle(
                color: kInkSoft.withValues(alpha:0.6),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasContent => _result.isNotEmpty || _error != null || _loading;

  Widget _loadingHint() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: kYellow, strokeWidth: 2.2),
        ),
        const SizedBox(width: 10),
        Text(
          '正在翻译…',
          style: TextStyle(color: kInkSoft.withValues(alpha:0.8), fontSize: 14),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.wifi_off_rounded, color: kYellowDark, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: kInk, fontSize: 14, height: 1.4),
          ),
        ),
        TextButton(
          onPressed: _translate,
          style: TextButton.styleFrom(foregroundColor: kYellowDark),
          child: const Text('重试'),
        ),
      ],
    );
  }
}
