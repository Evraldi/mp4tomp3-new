// List of supported audio formats and their properties
const List<Map<String, dynamic>> audioFormatOptions = [
  {
    'name': 'MP3',
    'extension': 'mp3',
    'bitrateOptions': [
      {'quality': 'High', 'value': '320k'},
      {'quality': 'Good', 'value': '192k'},
      {'quality': 'Medium', 'value': '128k'},
      {'quality': 'Low', 'value': '64k'},
    ],
  },
  {
    'name': 'AAC',
    'extension': 'm4a',
    'bitrateOptions': [
      {'quality': 'High', 'value': '256k'},
      {'quality': 'Good', 'value': '192k'},
      {'quality': 'Medium', 'value': '128k'},
    ],
  },
  {
    'name': 'WAV',
    'extension': 'wav',
    'bitrateOptions': [
      {'quality': 'Lossless', 'value': '1411k'},
    ],
  },
  {
    'name': 'OGG',
    'extension': 'ogg',
    'bitrateOptions': [
      {'quality': 'High', 'value': '256k'},
      {'quality': 'Good', 'value': '192k'},
      {'quality': 'Medium', 'value': '128k'},
    ],
  },
];
