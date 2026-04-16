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

// List of supported video formats
const List<Map<String, dynamic>> videoFormatOptions = [
  {
    'name': 'MP4',
    'extension': 'mp4',
  },
  {
    'name': 'MKV',
    'extension': 'mkv',
  },
  {
    'name': 'AVI',
    'extension': 'avi',
  },
];

// List of supported video compression options
const List<Map<String, dynamic>> videoCompressionOptions = [
  {
    'name': '1080p (High Quality)',
    'resolution': '1920:1080',
    'crf': '23',
  },
  {
    'name': '720p (Good Quality)',
    'resolution': '1280:720',
    'crf': '28',
  },
  {
    'name': '480p (Medium Quality / Smaller Size)',
    'resolution': '854:480',
    'crf': '32',
  },
  {
    'name': '360p (Low Quality / Smallest Size)',
    'resolution': '640:360',
    'crf': '35',
  },
];
