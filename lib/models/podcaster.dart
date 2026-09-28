class Podcaster {
  final String id;
  final String name;
  final String showTitle;
  final String avatarUrl;
  final String region; // 'India' or 'Global'
  final String countryFlag;
  final String tag;
  final String searchQuery;
  final String followerCount;

  const Podcaster({
    required this.id,
    required this.name,
    required this.showTitle,
    required this.avatarUrl,
    required this.region,
    required this.countryFlag,
    required this.tag,
    required this.searchQuery,
    required this.followerCount,
  });

  /// Alias getter for convenience / backwards compatibility
  String get followers => followerCount;

  static const List<Podcaster> curatedList = [
    // ─── India Creators ───
    Podcaster(
      id: 'trs_ranveer',
      name: 'Ranveer Allahbadia',
      showTitle: 'The Ranveer Show (TRS)',
      avatarUrl: 'https://yt3.googleusercontent.com/jWfhN0EdyRzwGZZimiTBMiqUuOOR0WIgdFINVOeb2oHSADRT47GUho-qh26OW2UYkbLnYXpP5A=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Mindset & Culture',
      searchQuery: 'The Ranveer Show podcast',
      followerCount: '9.8M',
    ),
    Podcaster(
      id: 'raj_shamani',
      name: 'Raj Shamani',
      showTitle: 'Figuring Out',
      avatarUrl: 'https://yt3.googleusercontent.com/qSVJkhoSs6lw5cNMsZAJ8ZAk1pxiewDb_gLtnzOsyM5TWQ6YggQj0eBetOLSxFuJqgxsyQ73NA=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Startups & Wealth',
      searchQuery: 'Figuring Out Raj Shamani',
      followerCount: '4.5M',
    ),
    Podcaster(
      id: 'pgx_prakhar',
      name: 'Prakhar Gupta',
      showTitle: 'Prakhar ke Pravachan',
      avatarUrl: 'https://yt3.googleusercontent.com/sNkEvcUGz8EnhYorYVtrVNa577Qn487Jr5qNEal4MQ2neMhmOoFZgSPv3lsdA_--qhL2wzR-Lyg=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Ideas & Philosophy',
      searchQuery: 'Prakhar ke Pravachan podcast',
      followerCount: '1.2M',
    ),
    Podcaster(
      id: 'nikhil_kamath',
      name: 'Nikhil Kamath',
      showTitle: 'WTF Podcast',
      avatarUrl: 'https://yt3.googleusercontent.com/XGYri31DcKi98pan5DYErwHPuPSQbUX97DpRzp-652rpXvrXuokR_YJrSdm6LJJORJkTvL7kBF0=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Business & Billionaires',
      searchQuery: 'WTF Nikhil Kamath podcast',
      followerCount: '2.8M',
    ),
    Podcaster(
      id: 'dhruv_rathee',
      name: 'Dhruv Rathee',
      showTitle: 'Maha Bharat Podcast',
      avatarUrl: 'https://yt3.googleusercontent.com/ATJuCH36wHPiFwumVBm423ouLVGQtq2pkPMOlSCclqqXErazOWyl4n07MRmbFnSJTL5P02Fq=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Current Affairs & History',
      searchQuery: 'Maha Bharat Dhruv Rathee podcast',
      followerCount: '28M',
    ),
    Podcaster(
      id: 'sandeep_maheshwari',
      name: 'Sandeep Maheshwari',
      showTitle: 'The Sandeep Maheshwari Show',
      avatarUrl: 'https://yt3.googleusercontent.com/5Egj8H7GT92E1dQZYhQuFvzInqR1iPo2YuXwJDcdO-qjRKuDNKuzjrQ7sxmjIP31j3Io0m6mATw=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Life, Mind & Motivation',
      searchQuery: 'Sandeep Maheshwari podcast',
      followerCount: '29M',
    ),
    Podcaster(
      id: 'tanmay_bhat',
      name: 'Tanmay Bhat',
      showTitle: 'Overpowered',
      avatarUrl: 'https://yt3.googleusercontent.com/LukgJ1t2G6jKYHGlMg4goXBd0z47PK8sXx611KLj-RY7L9sdKAvY4zbb-sYDtq-s5EqkzQnpkg=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Comedy & Internet Culture',
      searchQuery: 'Tanmay Bhat podcast',
      followerCount: '5.2M',
    ),
    Podcaster(
      id: 'ankur_warikoo',
      name: 'Ankur Warikoo',
      showTitle: 'Woice with Warikoo',
      avatarUrl: 'https://yt3.googleusercontent.com/Xmf5LtdlD2A7hOScjvc0nh87d1YfbfF458lN7Ot5T1a1CQePP6vNEmhZuj0x0TSz-37DBMzUsw=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Career & Personal Finance',
      searchQuery: 'Woice with Warikoo',
      followerCount: '4.1M',
    ),
    Podcaster(
      id: 'cyrus_broacha',
      name: 'Cyrus Broacha',
      showTitle: 'Cyrus Says',
      avatarUrl: 'https://yt3.googleusercontent.com/DxA8G674VdaYBOdDmzOwP9sJGXdIva27mf-RDfyMaOTMbUwzVykII8IUDkZ_7awes_O8bpbz=s900-c-k-c0x00ffffff-no-rj',
      region: 'India',
      countryFlag: '🇮🇳',
      tag: 'Satire & Daily Banter',
      searchQuery: 'Cyrus Says podcast',
      followerCount: '750K',
    ),

    // ─── Global Creators ───
    Podcaster(
      id: 'andrew_huberman',
      name: 'Dr. Andrew Huberman',
      showTitle: 'Huberman Lab',
      avatarUrl: 'https://yt3.googleusercontent.com/Y8lhyl8aHY42phxwoAwUqwLGDp-z8nmtj3Z7_JB-Oh4yIZ1OFYb-MlJRuz_oygqsYQU-VgGqiOM=s900-c-k-c0x00ffffff-no-rj',
      region: 'Global',
      countryFlag: '🌍',
      tag: 'Neuroscience & Protocols',
      searchQuery: 'Huberman Lab podcast full episode',
      followerCount: '6.5M',
    ),
    Podcaster(
      id: 'joe_rogan',
      name: 'Joe Rogan',
      showTitle: 'The Joe Rogan Experience',
      avatarUrl: 'https://yt3.googleusercontent.com/ytc/AIdro_kIOv8XSayB3mVzdmGH6r6nOuncclc_QxWr7TYTXM4dFrs=s900-c-k-c0x00ffffff-no-rj',
      region: 'Global',
      countryFlag: '🌍',
      tag: 'Culture, Comedy & Science',
      searchQuery: 'The Joe Rogan Experience full episode',
      followerCount: '17.5M',
    ),
    Podcaster(
      id: 'lex_fridman',
      name: 'Lex Fridman',
      showTitle: 'Lex Fridman Podcast',
      avatarUrl: 'https://yt3.googleusercontent.com/ytc/AIdro_ljfMy9kUR1PH9VRf-XsTsPqFMgORC_zodOQVEAm4hx36lC=s900-c-k-c0x00ffffff-no-rj',
      region: 'Global',
      countryFlag: '🌍',
      tag: 'AI, History & Deep Tech',
      searchQuery: 'Lex Fridman podcast full episode',
      followerCount: '4.8M',
    ),
    Podcaster(
      id: 'mel_robbins',
      name: 'Mel Robbins',
      showTitle: 'The Mel Robbins Podcast',
      avatarUrl: 'https://yt3.googleusercontent.com/0k8TKNmLHIMquCtAvJPHB8u1Uy1vzb89aYghWZY8CRtKOkfMVmTBlUXvW2GoA3nTpVnputYuJw=s900-c-k-c0x00ffffff-no-rj',
      region: 'Global',
      countryFlag: '🌍',
      tag: 'Habits & Transformation',
      searchQuery: 'Mel Robbins podcast',
      followerCount: '3.2M',
    ),
  ];
}
