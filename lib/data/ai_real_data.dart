/// Manifest for حقيقي ولا AI — the "real photograph or AI-generated?"
/// voting game. Half the items are REAL licensed photographs, half are
/// AI-generated images.
///
/// Real photos: Lorem Picsum (picsum.photos), which serves real Unsplash
/// photographs under the Unsplash license (free for commercial use, no
/// attribution required; authors credited in 'credit' anyway).
/// AI images: generated in-house after the nightly image-quota reset from
/// the 'prompt' briefs below (photorealistic, subtle tells, no text).
const List<Map<String, dynamic>> aiRealItems = [
  {
    'id': 'real_60',
    'asset': 'assets/aireal/real_60.jpg',
    'isAI': false,
    'explain': 'حقيقية! صورة مكتب حقيقية بعدسة المصور Vadim Sherbakov.',
    'credit': 'Vadim Sherbakov / Unsplash via Picsum #60',
  },
  {
    'id': 'ai_01',
    'asset': 'assets/aireal/ai_01.png',
    'isAI': true,
    'explain':
        'AI! الصورة متولدة.. الضل بيقع في اتجاهين مختلفين والحواف حوالين الكوباية مموهة.',
    'prompt':
        'photorealistic image of a glass of mint tea on a Cairo balcony table at sunset, AI-generated look with subtle inconsistencies: shadows falling in two directions, slightly waxy glass edges, no text',
  },
  {
    'id': 'real_61',
    'asset': 'assets/aireal/real_61.jpg',
    'isAI': false,
    'explain': 'حقيقية! صورة مدينة أوروبية بالأبيض والأسود من كاميرا حقيقية.',
    'credit': 'Alex / Unsplash via Picsum #61',
  },
  {
    'id': 'ai_02',
    'asset': 'assets/aireal/ai_02.png',
    'isAI': true,
    'explain':
        'AI! بص على إيد البنت.. الصوابع مدموجة ومش طبيعية، علامة توليد كلاسيكية.',
    'prompt':
        'photorealistic image of a girl laughing while holding a koshari bowl, AI-generated with subtly fused fingers on the visible hand, overly smooth skin, no text',
  },
  {
    'id': 'real_63',
    'asset': 'assets/aireal/real_63.jpg',
    'isAI': false,
    'explain':
        'حقيقية! فنجان قهوة باللبن على خلفية حمرا، إضاءة استوديو حقيقية.',
    'credit': 'Justin Leibow / Unsplash via Picsum #63',
  },
  {
    'id': 'ai_03',
    'asset': 'assets/aireal/ai_03.png',
    'isAI': true,
    'explain':
        'AI! عدّ عجلات التوك توك.. والكتابة على الاستيكر حروفها مبهدلة مش عربي صح.',
    'prompt':
        'photorealistic image of a tuk-tuk on a busy Egyptian street, AI-generated with garbled fake-Arabic sticker text and a slightly impossible wheel, no readable text',
  },
  {
    'id': 'real_66',
    'asset': 'assets/aireal/real_66.jpg',
    'isAI': false,
    'explain': 'حقيقية! وادي وجبال تحت سما غيم، صورة طبيعة حقيقية.',
    'credit': 'Nicholas Swanson / Unsplash via Picsum #66',
  },
  {
    'id': 'ai_04',
    'asset': 'assets/aireal/ai_04.png',
    'isAI': true,
    'explain':
        'AI! النجوم في السما متكررة بنفس الشكل، والقمر انعكاسه في البحر مش تحته.',
    'prompt':
        'photorealistic night seascape with a full moon over calm water, AI-generated with repeating identical star patterns and a moon reflection offset from the moon, no text',
  },
  {
    'id': 'real_74',
    'asset': 'assets/aireal/real_74.jpg',
    'isAI': false,
    'explain': 'حقيقية! بحر ومركب ومدينة على الضفة التانية.. صورة حقيقية.',
    'credit': 'Isaak Dury / Unsplash via Picsum #74',
  },
  {
    'id': 'ai_05',
    'asset': 'assets/aireal/ai_05.png',
    'isAI': true,
    'explain':
        'AI! القط عنده زايلتين لو بصيت كويس، وفره بينعكس غلط في المراية.',
    'prompt':
        'photorealistic image of an orange cat sleeping on a windowsill, AI-generated with a subtly doubled tail and slightly wrong fur detail, no text',
  },
  {
    'id': 'real_78',
    'asset': 'assets/aireal/real_78.jpg',
    'isAI': false,
    'explain': 'حقيقية! باب خشب قديم في شارع أوروبي، تفاصيل الحيطة طبيعية.',
    'credit': 'Paul Evans / Unsplash via Picsum #78',
  },
  {
    'id': 'ai_06',
    'asset': 'assets/aireal/ai_06.png',
    'isAI': true,
    'explain': 'AI! الفواكه كلها لمعة واحدة زي البلاستيك، والسكينة من غير ظل.',
    'prompt':
        'photorealistic still life of a fruit basket and a knife on a wooden table, AI-generated with uniformly plastic-looking fruit and a knife casting no shadow, no text',
  },
];
