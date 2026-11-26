/// Manifest for حقيقي ولا خدعة — the photo "real or fake?" voting game.
///
/// Each item is one photo shown to the whole group. Half are REAL photos of
/// ordinary scenes; half are fakes carrying one impossible or tampered
/// detail. [explain] is revealed after the vote and names the trick (or
/// confirms nothing was wrong). [prompt] is the image-generation brief used
/// to (re)create the asset — art is regenerated after the nightly quota
/// reset, alternating real-looking vs subtly-faked as flagged here.
const List<Map<String, dynamic>> bluffItems = [
  {
    'id': 'bluff_01',
    'asset': 'assets/bluff/bluff_01.png',
    'claim': 'قط قاعد جنب فنجان قهوة على ترابيزة خشب',
    'isReal': true,
    'explain':
        'صورة عادية جداً.. القط والفنجان والضل مظبوطين. مفيش أي حاجة متلعبة فيها!',
    'prompt':
        'realistic amateur smartphone photo of a ginger cat sitting next to a small Turkish coffee cup on a wooden table, natural window light, slightly imperfect framing, no edits',
  },
  {
    'id': 'bluff_02',
    'asset': 'assets/bluff/bluff_02.png',
    'claim': 'كلب بيشرب من نافورة في شارع',
    'isReal': false,
    'explain':
        'خدعة! بص على المية.. بتطلع من النافورة وبتلف لفوق بدل ما تنزل. المية مش بتطير كده!',
    'prompt':
        'photo of a dog drinking from a street water fountain but the water stream curves impossibly upward against gravity, otherwise photorealistic, subtle physics error, no text',
  },
  {
    'id': 'bluff_03',
    'asset': 'assets/bluff/bluff_03.png',
    'claim': 'غروب على كورنيش النيل والمراكب واقفة',
    'isReal': true,
    'explain':
        'حقيقية! الغروب والمراكب وانعكاسهم في المية كلهم طبيعيين.. عينك كانت سليمة.',
    'prompt':
        'realistic sunset photo over the Nile corniche with moored felucca boats, warm orange sky, natural water reflections, amateur photography style',
  },
  {
    'id': 'bluff_04',
    'asset': 'assets/bluff/bluff_04.png',
    'claim': 'بائع برتقان في السوق وقدامه طابور برتقان متراص',
    'isReal': false,
    'explain':
        'خدعة! في برتقانة واقفة في الهوا فوق الطابور من غير ما تمسك في حاجة. الجاذبية مش رأي!',
    'prompt':
        'photo of an orange seller stall in an Egyptian market with stacked oranges, but one orange floats impossibly in mid-air above the pile, otherwise photorealistic, subtle',
  },
  {
    'id': 'bluff_05',
    'asset': 'assets/bluff/bluff_05.png',
    'claim': 'بنت بتطير طائرة ورق على سطح بيت',
    'isReal': true,
    'explain':
        'حقيقية! البنت والطائرة والخيط والضل كلهم مظبوطين. الجولة دي كانت سهلة 😄',
    'prompt':
        'realistic photo of a girl flying a paper kite on a Cairo rooftop at golden hour, clothesline in background, natural pose, amateur smartphone quality',
  },
  {
    'id': 'bluff_06',
    'asset': 'assets/bluff/bluff_06.png',
    'claim': 'عربية كيا قديمة متوقفة جنب سور',
    'isReal': false,
    'explain':
        'خدعة! عدّ العجلات.. العربية واقفة على 3 عجلات بس، والرابعة مختفية خالص من الصورة!',
    'prompt':
        'photo of an old sedan parked by a wall but the car has only three wheels, the fourth wheel completely missing with the car still level, otherwise photorealistic, subtle',
  },
  {
    'id': 'bluff_07',
    'asset': 'assets/bluff/bluff_07.png',
    'claim': 'طبق كشري من محل شعبي',
    'isReal': true,
    'explain': 'حقيقية! الكشري والدقة واللمون.. كل حاجة في مكانها. حد جوع؟',
    'prompt':
        'realistic overhead photo of a plate of Egyptian koshari with lentils rice pasta fried onions and tomato sauce on a metal table in a casual restaurant, appetizing, natural light',
  },
  {
    'id': 'bluff_08',
    'asset': 'assets/bluff/bluff_08.png',
    'claim': 'راجل بيصطاد سمك من كوبري',
    'isReal': false,
    'explain':
        'خدعة! بص لإيديه.. عنده 6 صوابع في الإيد الماسكة الصنارة. التعديل نسي يعدّ الصوابع!',
    'prompt':
        'photo of a man fishing from a bridge holding a fishing rod, but his visible hand has six fingers, otherwise photorealistic, subtle anatomical error',
  },
  {
    'id': 'bluff_09',
    'asset': 'assets/bluff/bluff_09.png',
    'claim': 'عصير قصب طازة والكوبايات متصفطة',
    'isReal': true,
    'explain': 'حقيقية! القصب والعصارة والكوبايات طبيعيين.. ولا حاجة مشبوهة.',
    'prompt':
        'realistic photo of fresh sugarcane juice glasses lined up at an Egyptian juice cart, green stalks visible, condensation on glasses, natural daylight',
  },
  {
    'id': 'bluff_10',
    'asset': 'assets/bluff/bluff_10.png',
    'claim': 'حمامة واقفة على سلك كهربا',
    'isReal': false,
    'explain':
        'خدعة! الضل بتاع الحمامة واقع في الاتجاه المعاكس لضل العمود. الشمس عندها رأي واحد بس!',
    'prompt':
        'photo of a pigeon perched on an electric wire against a bright sky, but the pigeon shadow falls in the opposite direction of the pole shadow, inconsistent lighting, otherwise photorealistic',
  },
  {
    'id': 'bluff_11',
    'asset': 'assets/bluff/bluff_11.png',
    'claim': 'ولاد بيلعبوا كورة في حارة',
    'isReal': true,
    'explain':
        'حقيقية! الولاد والكورة والحارة كلها طبيعية.. حتى الكورة مش بتطير غلط.',
    'prompt':
        'realistic photo of kids playing football in a narrow Egyptian alley, ball mid-kick, laundry hanging overhead, motion and joy, amateur smartphone photo',
  },
  {
    'id': 'bluff_12',
    'asset': 'assets/bluff/bluff_12.png',
    'claim': 'كباية شاي على صاج قديم',
    'isReal': false,
    'explain':
        'خدعة! البخار طالع من الكباية بس الصاج تحتها ساكت.. والانعكاس في الصاج مفيهوش كباية أصلاً!',
    'prompt':
        'photo of a glass tea cup on an old shiny brass tray, steam rising, but the tray reflection shows no cup at all, missing reflection, otherwise photorealistic, subtle',
  },
];
