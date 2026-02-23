import 'package:muzik/models/voice_intent.dart';

class VoiceAssistantService {
  /// Processes a natural language command and returns a VoiceIntent.
  VoiceIntent processCommand(String command) {
    final originalCommand = command;
    String input = command.toLowerCase().trim();

    // 1. Pre-processing
    // Remove wake word
    input = input.replaceAll(RegExp(r'^hey\s+mei,?\s*', caseSensitive: false), '');

    // Clean string but keep essential chars for various languages
    // \u00C0-\u017F covers many European accented chars
    String cleanInput = input.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ');
    cleanInput = cleanInput.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanInput.isEmpty) return VoiceIntent(intent: IntentType.UNKNOWN);

    // 2. Value Extraction (Volume, Seconds)
    final numbers = RegExp(r'(\d+)').allMatches(cleanInput).map((m) => int.parse(m.group(1)!)).toList();
    int? firstValue = numbers.isNotEmpty ? numbers.first : null;

    // 3. Intent Logic - Prioritized

    // SET_VOLUME (Look for volume keywords + a number)
    if (_hasAny(cleanInput, ['volume', 'ses', 'volumen', 'son', 'lautstärke', 'volume']) && firstValue != null) {
      if (!_hasAny(cleanInput, ['up', 'down', 'aç', 'kıs', 'artır', 'azalt', 'yükselt', 'düşür'])) {
         return VoiceIntent(intent: IntentType.SET_VOLUME, volume: firstValue.clamp(0, 100));
      }
    }

    // NEXT (Track skip)
    if (_hasAny(cleanInput, ['next', 'sonraki', 'sıradaki', 'siguiente', 'suivant', 'nächste', 'prossimo', 'geç', 'atla'])) {
      // "Skip forward" should be handled as seek, so check for seek keywords
      if (!_hasAny(cleanInput, ['forward', 'backward', 'ileri', 'geri', 'saniye', 'seconds'])) {
         return VoiceIntent(intent: IntentType.NEXT);
      }
    }

    // PREVIOUS
    if (_hasAny(cleanInput, ['previous', 'önceki', 'anterior', 'précédent', 'vorherige', 'precedente', 'geri'])) {
       if (!_hasAny(cleanInput, ['forward', 'backward', 'saniye', 'seconds'])) {
         return VoiceIntent(intent: IntentType.PREVIOUS);
       }
    }

    // SEEK_FORWARD
    if (_hasAny(cleanInput, ['forward', 'ileri', 'avancer', 'vorwärts', 'avanti']) ||
        (cleanInput.contains('skip') && _hasAny(cleanInput, ['forward', 'ileri', 'seconds', 'saniye']))) {
      return VoiceIntent(intent: IntentType.SEEK_FORWARD, seconds: firstValue ?? 10);
    }

    // SEEK_BACKWARD
    if (_hasAny(cleanInput, ['backward', 'geri sar', 'sarı', 'reculer', 'rückwärts', 'indietro']) ||
        (cleanInput.contains('back') && _hasAny(cleanInput, ['backward', 'geri', 'seconds', 'saniye']))) {
      return VoiceIntent(intent: IntentType.SEEK_BACKWARD, seconds: firstValue ?? 10);
    }

    // VOLUME_UP / DOWN
    if (_hasAny(cleanInput, ['louder', 'up', 'aç', 'yükselt', 'arttır', 'artir', 'más alto', 'plus fort', 'lauter', 'più alto'])) {
      return VoiceIntent(intent: IntentType.VOLUME_UP);
    }
    if (_hasAny(cleanInput, ['quieter', 'down', 'kıs', 'kis', 'düşür', 'azalt', 'más bajo', 'plus bas', 'leiser', 'più basso'])) {
      return VoiceIntent(intent: IntentType.VOLUME_DOWN);
    }

    // PAUSE
    if (_hasAny(cleanInput, ['pause', 'stop', 'dur', 'durdur', 'kes', 'pausa', 'arrêter', 'stoppen', 'ferma'])) {
      return VoiceIntent(intent: IntentType.PAUSE);
    }

    // PLAY / RESUME
    final playKeywords = ['play', 'oynat', 'resume', 'devam et', 'başlat', 'çal', 'aç', 'dinlet', 'reproducir', 'jouer', 'spielen', 'riproduci'];
    if (playKeywords.contains(cleanInput) || _hasAny(cleanInput, ['resume', 'devam et'])) {
      return VoiceIntent(intent: IntentType.PLAY);
    }

    // PLAY_SONG
    // If it starts with a play verb or ends with one (like Turkish 'çal')
    for (var kw in playKeywords) {
      if (cleanInput.contains(kw)) {
        String songName = cleanInput.replaceAll(kw, '').trim();
        if (songName.isNotEmpty) {
           // Remove common conjunctions and filler words in various languages
           songName = songName.replaceAll(RegExp(r'\b(şarkısını|şarkı|lütfen|bir|the|by|de|von|di)\b'), '').trim();
           if (songName.isNotEmpty && songName.length > 2) {
             return VoiceIntent(intent: IntentType.PLAY_SONG, songName: songName);
           }
        }
      }
    }

    // Catch-all for song names if it's multiple words
    if (cleanInput.split(' ').length >= 2) {
       return VoiceIntent(intent: IntentType.PLAY_SONG, songName: cleanInput);
    }

    return VoiceIntent(intent: IntentType.UNKNOWN);
  }

  bool _hasAny(String input, List<String> keywords) {
    for (var kw in keywords) {
      // Use word boundaries for better matching if possible, or just contains
      if (input.contains(kw)) return true;
    }
    return false;
  }
}
