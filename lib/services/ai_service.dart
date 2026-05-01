import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'ai_cache_service.dart';
import 'supabase_service.dart';

class AIService {
  /// Generates questions for a specific category using GitHub Models AI.
  static Future<List<Map<String, dynamic>>> fetchAiQuestions(
    String category, {
    int count = 10,
    List<String>? history,
  }) async {
    final historyPrompt = (history != null && history.isNotEmpty)
        ? '\nتجنب تكرار هذه الأسئلة التي تم توليدها سابقاً: ${history.join(" و ")}'
        : '';
    final prompt =
        '''
ولد $count أسئلة **صعبة جداً ومخصصة للمحترفين** في فئة "$category" باللغة العربية. 
$historyPrompt
تأكد من أن الأسئلة تتطلب تفكيراً عميقاً ومعلومات عامة واسعة (مستوى التحدي: عالٍ جداً).
يجب أن يكون الرد بتنسيق JSON فقط كقائمة من الكائنات.
كل كائن يحتوي على المفاتيح التالية: "question" و "answer".
تأكد من أن الأسئلة ممتعة وغير مكررة.
مثال للتنسيق:
[
  {"question": "سؤال تحدي صعبة", "answer": "إجابة دقيقة"}
]
]
''';
    final result = await _fetchContent(prompt);
    if (result.isNotEmpty) {
      await AICacheService.saveQuizQuestions(category, result);
      // Push to Community Database
      for (var item in result) {
        SupabaseService.uploadContent(
          gameKey: 'quiz',
          category: category,
          content: item,
          creatorId: SettingsService.deviceId,
          creatorName: SettingsService.userName.isEmpty ? "مستخدم مجهول" : SettingsService.userName,
        ).catchError((_) {}); // Non-blocking
      }
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> fetchGameContent(
    String gameType, {
    int count = 10,
    List<String>? history,
  }) async {
    final historyPrompt = (history != null && history.isNotEmpty)
        ? '\nتجنب تكرار هذه العناصر التي تم توليدها سابقاً: ${history.join(", ")}'
        : '';
    String specificPrompt = '';

    switch (gameType) {
      case 'jokes':
        specificPrompt =
            'ولد $count نكت مصرية وعربية مضحكة جداً جداً وتموت من الضحك، مستوحاة من أسلوب السوشيال ميديا المودرن وموقع "التكية". ممنوع تماماً النكت البايخة، القديمة، أو الفصيلة. ركز على النكت الذكية، القلش العالي، والمواقف اللي بتعصب من كتر ما هي بتضحك. التنسيق: [{"joke": "...", "icon": "😂"}]';
        break;
      case 'letter_bomb':
        specificPrompt =
            'ولد $count تصنيفات لألعاب القنبلة الموقوتة (فئة وحرف وأمثلة). يجب أن تكون الحروف المختارة لها أمثلة كثيرة وشائعة جداً في تلك الفئة. التنسيق: [{"category": "...", "letter": "...", "examples": ["...", "..."]}]';
        break;
      case 'five_seconds':
        specificPrompt =
            'ولد $count أسئلة صعبة للعبة الـ 5 ثواني (تطلب ذكر 3 أشياء). التنسيق: [{"question": "..."}]';
        break;
      case 'reverse_quiz':
        specificPrompt =
            'ولد $count أسئلة معكوسة (بعطيك الإجابة والمستخدم يحذر السؤال). التنسيق: [{"answer": "...", "question": "..."}]';
        break;
      case 'who_am_i':
        specificPrompt =
            'ولد بالضبط $count شخصية مشهورة متنوعة (ممثلين، لاعبين، علماء، شخصيات تاريخية). لكل شخصية قدم 3 تلميحات تدريجية في الصعوبة. التنسيق: [{"name": "اسم الشخصية", "hints": ["تلميح 1", "تلميح 2", "تلميح 3"], "icon": "إيموجي مناسب"}]';
        break;
      case 'truth_or_dare':
        specificPrompt =
            'ولد $count طلبات حقيقة وجرأة (منوعة وجريئة). التنسيق: [{"type": "truth|dare", "prompt": "..."}]';
        break;

      case 'pictionary':
        specificPrompt =
            'ولد بالضبط $count كلمات بسيطة جداً ومكونة من كلمة واحدة فقط (مثلاً: شجرة، كلب، بيت) وممتعة للرسم والتخمين. التنسيق: [{"word": "الكلمة", "category": "اسم الفئة"}]';
        break;
      case 'charades':
        specificPrompt =
            'ولد $count فئات (categories) متنوعة للتمثيل الصامت (أفلام، أفعال، مهن، أشياء). وفي كل فئة، قم بتوليد 15 كلمة صعبة وممتعة للتمثيل. التنسيق: [{"category": "اسم الفئة", "words": ["كلمة 1", "كلمة 2", ...]}]';
        break;
      case 'truth_or_lie':
        specificPrompt =
            'ولد $count حقائق مدهشة (منها حقيقي ومنها هبد) مع تعليل. التنسيق: [{"statement": "...", "is_true": true|false, "explanation": "..."}]';
        break;
      case 'definition':
        specificPrompt =
            'ولد $count كلمات صعبة مع تعريفات دقيقة لها للعبة تحدي التعريف. التنسيق: [{"word": "...", "definition": "..."}]';
        break;
      case 'odd_one_out':
        specificPrompt =
            'ولد $count أسئلة للعبة "الاختيار الثالث". كل سؤال يحتوي على 6 عناصر، 5 منهم مرتبطين جداً ببعض منطقياً، وعنصر واحد مختلف تماماً (الـ odd one). التنسيق: [{"items": ["...", "...", "...", "...", "...", "..."], "oddOne": "...", "reason": "سبب الاختلاف بالعامية المصرية", "icon": "emoji"}]';
        break;
      case 'word_chain_game':
        specificPrompt =
            'ولد $count فئات (categories) للعبة "تحدي التعريف". كل فئة تحتوي على $count كلمات صعبة ومختلفة للتمثيل بالشرح (بدون نطق الكلمة). التنسيق: [{"category": "اسم الفئة", "words": ["كلمة 1", "كلمة 2", ...]}]';
        break;
      case 'opposite_day':
        specificPrompt =
            'ولد $count أسئلة للعبة "عكس العكاس". كل سؤال عبارة عن حقيقة بسيطة جداً والمطلوب من اللاعب يقول عكسها. التنسيق: [{"question": "سؤال بسيط", "forbidden": ["الرد الصح", "مرادف للرد الصح"], "icon": "emoji"}]';
        break;
      case 'quiz':
        specificPrompt =
            'ولد $count أسئلة مسابقات (General Knowledge) متنوعة وصعبة. كل سؤال له 4 اختيارات وإجابة واحدة صحيحة. التنسيق: [{"question": "...", "options": ["...", "...", "...", "..."], "answer": "الاختيار الصح", "category": "فئة السؤال"}]';
        break;
      default:
        specificPrompt =
            'ولد $count محتوى لهذه اللعبة: $gameType باللغة العربية. التنسيق: [{"text": "..."}]';
    }

    final prompt =
        '''
$specificPrompt
$historyPrompt
يجب أن يكون الرد بتنسيق JSON فقط كقائمة من الكائنات.
اللغة: العربية.
تأكد من أن المحتوى ممتع، جديد، وغير مكرر.
''';

    final result = await _fetchContent(prompt);
    // Exclude certain game types from caching if they depend dynamically on answers like word_chain or who_am_i hints too heavily? 
    // Actually who_am_i is fine to cache. We can cache all.
    if (result.isNotEmpty) {
      await AICacheService.saveGameContent(gameType, result);
      // Push to Community Database
      for (var item in result) {
        String? cat;
        if (item is Map) {
          cat = (item['category'] ?? item['cat'])?.toString();
        }
        SupabaseService.uploadContent(
          gameKey: gameType,
          category: cat,
          content: item is Map ? Map<String, dynamic>.from(item) : {'content': item},
          creatorId: SettingsService.deviceId,
          creatorName: SettingsService.userName.isEmpty ? "مستخدم مجهول" : SettingsService.userName,
        ).catchError((_) {}); // Non-blocking
      }
    }
    return result;
  }

  /// Generates a ranked list of [count] items for [topic] in Arabic.
  /// Returns a list of strings ordered from rank #1 to rank #count.
  static Future<List<String>> fetchRankedList(String topic, int count) async {
    final prompt = '''
ولّد قائمة مرتبة من أفضل $count عنصر للموضوع التالي: "$topic".
رتبهم من الأهم/الأشهر/الأفضل (رقم 1) إلى الأقل (رقم $count).
يجب أن يكون الرد بتنسيق JSON فقط كقائمة من الكائنات.
كل كائن له مفتاح "item" فقط.
مثال: [{"item": "مصر"}, {"item": "فرنسا"}, ...]
اللغة: العربية. تأكد أن القائمة فيها بالضبط $count عنصر.
''';
    final raw = await _fetchContent(prompt);
    return raw
        .map((e) => e['item']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Scores [playerAnswers] against the [rankedList] using fuzzy/approximate matching.
  /// Returns a map: playerAnswer -> {rank: int (1-based, 0 = not found), matched: String}
  static Future<Map<String, Map<String, dynamic>>> scorePlayerAnswers(
    List<String> playerAnswers,
    List<String> rankedList,
  ) async {
    final listText = rankedList
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final answersText = playerAnswers.map((a) => '"$a"').join('، ');
    final prompt = '''
عندك قائمة مرتبة:
$listText

وعندك إجابات لاعبين: $answersText

لكل إجابة، ابحث في القائمة بشكل تقريبي (اقبل الأخطاء الإملائية والكلمات المختلفة اللي بتعني نفس الشيء مثلاً "امريكان" = "الولايات المتحدة").
أرجع JSON كقائمة من الكائنات: [{"answer": "إجابة اللاعب", "rank": رقم الترتيب أو 0 لو مش موجود, "matched": "العنصر اللي اتطابق من القائمة أو فارغ لو مش موجود"}]
''';
    final raw = await _fetchContent(prompt);
    final result = <String, Map<String, dynamic>>{};
    for (final entry in raw) {
      final answer = entry['answer']?.toString() ?? '';
      if (answer.isNotEmpty) {
        result[answer] = {
          'rank': (entry['rank'] as num?)?.toInt() ?? 0,
          'matched': entry['matched']?.toString() ?? '',
        };
      }
    }
    return result;
  }

  /// Generates a raw string response for custom prompts.
  static Future<String> generateRawResponse(String prompt) async {
    final tokens = SettingsService.githubTokens;
    if (tokens.isEmpty) {
      throw Exception('GitHub Tokens are missing.');
    }

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      try {
        final response = await http.post(
          Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'messages': [
              {
                'role': 'system',
                'content': 'You are a professional game judge and content creator.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'model': 'gpt-4o',
            'temperature': 0.7,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return data['choices'][0]['message']['content'] as String;
        }
        if (response.statusCode == 429 && i < tokens.length - 1) continue;
      } catch (e) {
        if (i < tokens.length - 1) continue;
        rethrow;
      }
    }
    throw Exception('Failed to generate AI response.');
  }

  static Future<List<Map<String, dynamic>>> _fetchContent(String prompt) async {
    final tokens = SettingsService.githubTokens;
    if (tokens.isEmpty) {
      throw Exception('GitHub Tokens are missing. Please set them in Settings.');
    }

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      try {
        final response = await http.post(
          Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a professional game content creator in Arabic.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'model': 'gpt-4o',
            'temperature': 0.8,
            'max_tokens': 4000,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices'][0]['message']['content'] as String;

          // Extract JSON using regex (in case there's markdown)
          final jsonRegex = RegExp(r'\[[\s\S]*\]');
          final match = jsonRegex.firstMatch(content);

          if (match != null) {
            final jsonStr = match.group(0)!;
            final List<dynamic> list = jsonDecode(jsonStr);
            return list.map((e) => Map<String, dynamic>.from(e)).toList();
          }

          throw Exception('فشل في قراءة البيانات من الـ AI.');
        } else if (response.statusCode == 429) {
          // Handle Rate Limit specifically
          final body = response.body;
          int waitSeconds = 0;
          try {
            final data = jsonDecode(body);
            final message = data['error']?['message']?.toString() ?? '';
            final match = RegExp(r'wait (\d+) seconds').firstMatch(message);
            if (match != null) {
              waitSeconds = int.parse(match.group(1)!);
            }
          } catch (_) {}

          // If we have more tokens, try the next one
          if (i < tokens.length - 1) {
            debugPrint('Token $i rate limited, trying next token...');
            continue;
          }

          if (waitSeconds > 0) {
            final minutes = (waitSeconds / 60).ceil();
            throw Exception(
                'لقد وصلت للحد اليومي للاستخدام (50 مرة لكل مفتاح). يرجى المحاولة بعد $minutes دقيقة تقريباً.');
          } else {
            throw Exception(
                'لقد وصلت للحد اليومي للاستخدام (100 مرة مجموع المفتاحين). يرجى المحاولة لاحقاً بعد حوالي نصف ساعة.');
          }
        } else {
          throw Exception('خطأ في الاتصال بالسيرفر (${response.statusCode})');
        }
      } on http.ClientException catch (e) {
        debugPrint('AI Service Network Error with token $i: $e');
        if (i < tokens.length - 1) continue;
        throw Exception('تأكد من اتصالك بالإنترنت وحاول مرة أخرى. (خطأ في الشبكة)');
      } catch (e) {
        debugPrint('AI Service Error with token $i: $e');
        if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
          if (i < tokens.length - 1) continue;
          throw Exception('مشكلة في الاتصال بالسيرفر. تأكد من جودة الإنترنت أو جرب تقفل الـ VPN.');
        }
        if (i < tokens.length - 1) continue;
        rethrow;
      }
    }
    throw Exception('حدث خطأ غير متوقع في خدمة الـ AI.');
  }
}
