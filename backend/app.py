from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests

app = Flask(__name__)
CORS(app)

ydl_opts = {
    'format': 'bestaudio/best',
    'quiet': True,
    'no_warnings': True,
    'socket_timeout': 30,
}

@app.route('/')
def home():
    return "Muzic API is running!"

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_stream(video_id):
    try:
        url = f'https://www.youtube.com/watch?v={video_id}'
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if 'url' in info:
                return jsonify({
                    'success': True,
                    'stream_url': info['url'],
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0),
                    'view_count': info.get('view_count', 0),
                    'like_count': info.get('like_count', 0),
                }), 200
            return jsonify({'error': 'No URL'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/lyrics/<video_id>', methods=['GET'])
def get_lyrics(video_id):
    try:
        url = f'https://www.youtube.com/watch?v={video_id}'
        # Şarkı sözlerini (altyazıları) çekmeye çalış
        ydl_lyrics_opts = {
            'skip_download': True,
            'writesubtitles': True,
            'writeautomaticsub': True,
            'subtitleslangs': ['tr', 'en'],
            'quiet': True,
        }
        with yt_dlp.YoutubeDL(ydl_lyrics_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            # Burada basitleştirilmiş bir mantık var, gerçek şarkı sözü API'leri daha karmaşıktır
            return jsonify({
                'success': True,
                'lyrics': "Şarkı sözleri YouTube altyazılarından çekilecek...",
                'subtitles': info.get('subtitles', {}),
                'automatic_captions': info.get('automatic_captions', {})
            }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/search', methods=['POST'])
def search():
    try:
        data = request.get_json()
        query = data.get('query', '')
        if not query: return jsonify({'error': 'Query empty'}), 400
        with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True}) as ydl:
            info = ydl.extract_info(f'ytsearch5:{query}', download=False)
            results = []
            if 'entries' in info:
                for entry in info['entries']:
                    results.append({
                        'video_id': entry.get('id'),
                        'title': entry.get('title'),
                        'uploader': entry.get('uploader', 'Unknown'),
                        'duration': entry.get('duration', 0),
                    })
            return jsonify({'success': True, 'results': results}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
