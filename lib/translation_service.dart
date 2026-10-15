import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 支持的语言
class Lang {
  final String code; // 翻译接口用代码
  final String label; // 界面显示
  const Lang(this.code, this.label);

  @override
  bool operator ==(Object other) => other is Lang && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const kLanguages = <Lang>[
  Lang('zh-CN', '中文'),
  Lang('en', '英语'),
  Lang('ja', '日语'),
  Lang('fr', '法语'),
  Lang('ru', '俄语'),
  Lang('de', '德语'),
  Lang('ko', '韩语'),
  Lang('th', '泰语'),
];

class TranslationResult {
  final String text;
  final String provider; // 来源标识，便于排查
  const TranslationResult({required this.text, required this.provider});
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  @override
  String toString() => message;
}

/// 免费公开翻译接口封装：
/// 1) Google translate gtx 非官方接口（快、质量好，部分地区不可达）
/// 2) MyMemory 兜底（无需 key，单次 500 字符内）
///
/// 两个源并发请求，谁先成功就用谁的结果。
class TranslationService {
  static const _timeout = Duration(seconds: 12);
  static const _mymemoryLimit = 480;

  final http.Client _client = http.Client();

  Future<TranslationResult> translate({
    required String text,
    required Lang from,
    required Lang to,
  }) async {
    final q = text.trim();
    if (q.isEmpty) return const TranslationResult(text: '', provider: 'none');
    if (from == to) return TranslationResult(text: q, provider: 'same');

    final completer = Completer<TranslationResult>();
    var pending = 2;

    void settle(TranslationResult? ok, Object? err) {
      if (ok != null && !completer.isCompleted) {
        completer.complete(ok);
        return;
      }
      pending--;
      if (pending == 0 && !completer.isCompleted) {
        completer.completeError(TranslationException('翻译失败，请检查网络后重试'));
      }
    }

    // 并发请求两个免费源，先到先用
    _viaGoogle(q, from, to)
        .then((r) => settle(r, null), onError: (Object e) => settle(null, e))
        .ignore();
    // 超长文本 MyMemory 会截断，只交给 Google
    if (q.length <= _mymemoryLimit) {
      _viaMyMemory(q, from, to)
          .then((r) => settle(r, null), onError: (Object e) => settle(null, e))
          .ignore();
    } else {
      settle(null, 'skipped');
    }

    return completer.future;
  }

  Future<TranslationResult> _viaGoogle(String q, Lang from, Lang to) async {
    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx&sl=${from.code}&tl=${to.code}&dt=t&q=${Uri.encodeComponent(q)}',
    );
    final res = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) {
      throw TranslationException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List || data.isEmpty || data[0] is! List) {
      throw TranslationException('响应格式异常');
    }
    final buf = StringBuffer();
    for (final seg in (data[0] as List)) {
      if (seg is List && seg.isNotEmpty && seg[0] is String) {
        buf.write(seg[0]);
      }
    }
    final out = buf.toString();
    if (out.isEmpty) throw TranslationException('空结果');
    return TranslationResult(text: out, provider: 'google');
  }

  Future<TranslationResult> _viaMyMemory(String q, Lang from, Lang to) async {
    // MyMemory 单次请求限制 500 字符
    final clipped = q.length > _mymemoryLimit ? q.substring(0, _mymemoryLimit) : q;
    final uri = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?langpair=${from.code}|${to.code}&q=${Uri.encodeComponent(clipped)}',
    );
    final res = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) {
      throw TranslationException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final status = data['responseStatus'];
    final out = data['responseData']?['translatedText'];
    if (status != 200 || out is! String || out.isEmpty) {
      throw TranslationException('MyMemory: $status');
    }
    return TranslationResult(text: _unescape(out), provider: 'mymemory');
  }

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (TranApp)',
    'Accept': 'application/json,text/plain,*/*',
  };

  /// MyMemory 偶尔会返回 HTML 转义实体
  static String _unescape(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  void dispose() => _client.close();
}
