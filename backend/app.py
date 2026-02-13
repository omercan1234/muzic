from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
from dotenv import load_dotenv
import requests

load_dotenv()

app = Flask(__name__)
CORS(app)

# Railway'in atadığı Public URL'yi al (veya Flutter'daki backendUrl ile aynı yap)
PUBLIC_URL = "https://muzic-production-a4ca.up.railway.app"

# youtube-dl options
ydl_opts = {
    'format': 'bestaudio/best',
    'quiet': True,
    'no_warnings': True,
    'socket_timeout': 30,
}

# Cache for video info (video_id -> {url, timestamp})
_video_cache = {}

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_stream(video_id):
    try:
        if not video_id or len(video_id) != 11:
            return jsonify({'error': 'Invalid video ID'}), 400

        url = f'https://www.youtube.com/watch?v={video_id}'

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            
            if 'url' in info:
                # LOCALHOST YERİNE PUBLIC URL KULLANMALIYIZ
                proxy_url = f'{PUBLIC_URL}/api/stream/{video_id}'
                
                return jsonify({
                    'success': True,
                    'stream_url': proxy_url,
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0),
                    'thumbnail': info.get('thumbnail', ''),
                }), 200
            else:
                return jsonify({'error': 'No stream URL found'}), 400
                
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stream/<video_id>', methods=['GET'])
def proxy_stream(video_id):
    try:
        if video_id in _video_cache:
            stream_url = _video_cache[video_id].get('url')
        else:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info.get('url')
                _video_cache[video_id] = {'url': stream_url}
        
        if not stream_url:
            return jsonify({'error': 'Stream URL not found'}), 400
        
        response = requests.get(stream_url, stream=True, timeout=300)
        return Response(
            stream_with_context(response.iter_content(chunk_size=8192)),
            content_type=response.headers.get('content-type', 'audio/mpeg')
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/status', methods=['GET'])
def status():
    return jsonify({'status': 'ok'}), 200

@app.route('/api/search', methods=['POST'])
def search():
    try:
        data = request.get_json()
        query = data.get('query', '')
        if not query: return jsonify({'error': 'Query required'}), 400
        
        ydl_opts_search = {'quiet': True, 'extract_flat': True}
        with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
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
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
