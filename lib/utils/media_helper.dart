// Deteksi media dokumentasi (foto/video) dari nama file atau URL.
const Set<String> kVideoExtensions = {
  'mp4', 'mov', 'webm', 'm4v', 'avi', 'mkv',
};

bool isVideoName(String name) {
  final clean = name.split('?').first;
  if (!clean.contains('.')) return false;
  return kVideoExtensions.contains(clean.split('.').last.toLowerCase());
}

bool isVideoUrl(String url) => isVideoName(url);
