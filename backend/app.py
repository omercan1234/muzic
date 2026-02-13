from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
from dotenv import load_dotenv
import requests

load_dotenv()

app = Flask(__name__)
CORS(app)

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
    """
    YouTube video'dan audio stream URL'sini al
    """
    try:
        # Video ID'yi doğrula
        if not video_id or len(video_id) != 11:
            return jsonify({'error': 'Invalid video ID'}), 400

        # YouTube URL'sini oluştur
        url = f'https://www.youtube.com/watch?v={video_id}'
        
        print(f'[INFO] Processing: {url}')
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            
            # En iyi audio stream'i al
            if 'url' in info:
                stream_url = info['url']
                
                # Stream URL'sini proxy endpoint'e değiştir (daha uzun ömürlü)
                proxy_url = f'http://localhost:5000/api/stream/{video_id}'
                
                return jsonify({
                    'success': True,
                    'stream_url': proxy_url,  # Proxy endpoint kullan
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0),
                    'thumbnail': info.get('thumbnail', ''),
                }), 200
            else:
                return jsonify({'error': 'No stream URL found'}), 400
                
    except yt_dlp.utils.DownloadError as e:
        print(f'[ERROR] Download error: {e}')
        return jsonify({'error': f'Download error: {str(e)}'}), 400
    except Exception as e:
        print(f'[ERROR] Exception: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/stream/<video_id>', methods=['GET'])
def proxy_stream(video_id):
    """
    YouTube stream'i proxy'le - daha uzun ömürlü connection
    """
    try:
        print(f'[INFO] Streaming: {video_id}')
        
        # Cache'den kontrol et
        if video_id in _video_cache:
            cached_info = _video_cache[video_id]
            stream_url = cached_info.get('url')
        else:
            # Yeni URL al
            url = f'https://www.youtube.com/watch?v={video_id}'
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info.get('url')
                
                # Cache'le (5 dakika)
                _video_cache[video_id] = {
                    'url': stream_url,
                    'title': info.get('title', 'Unknown'),
                }
        
        if not stream_url:
            return jsonify({'error': 'Stream URL not found'}), 400
        
        # Stream'i proxy'le
        response = requests.get(stream_url, stream=True, timeout=300)
        
        return Response(
            stream_with_context(response.iter_content(chunk_size=8192)),
            content_type=response.headers.get('content-type', 'audio/mpeg'),
            headers={
                'Content-Length': response.headers.get('content-length', ''),
                'Cache-Control': 'no-cache',
                'Accept-Ranges': 'bytes',
            }
        )
        
    except Exception as e:
        print(f'[ERROR] Proxy stream error: {e}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/status', methods=['GET'])
def status():
    """Health check"""
    return jsonify({
        'status': 'ok',
        'service': 'YouTube Music Stream API',
        'version': '1.0'
    }), 200

@app.route('/api/search', methods=['POST'])
def search():
    """
    YouTube'da şarkı ara
    """
    try:
        data = request.get_json()
        query = data.get('query', '')
        
        if not query:
            return jsonify({'error': 'Query required'}), 400
        
        print(f'[INFO] Searching: {query}')
        
        ydl_opts_search = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': 'in_playlist',
            'skip_download': True,
        }
        
        search_url = f'ytsearch10:{query}'
        
        with yt_dlp.YoutubeDL(ydl_opts_search) as ydl:
            info = ydl.extract_info(search_url, download=False)
            
            results = []
            if 'entries' in info:
                for entry in info['entries'][:5]:  # İlk 5 sonuç
                    results.append({
                        'video_id': entry.get('id'),
                        'title': entry.get('title'),
                        'uploader': entry.get('uploader', 'Unknown'),
                        'duration': entry.get('duration', 0),
                    })
            
            return jsonify({
                'success': True,
                'results': results
            }), 200
            
    except Exception as e:
        print(f'[ERROR] Search error: {e}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Production: Gunicorn kullan
    # Development:
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
