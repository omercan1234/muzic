from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests
from cachetools import TTLCache

app = Flask(__name__)
CORS(app)

# Linkleri 1 saat boyunca hafızada tutar (Hız için kritik)
url_cache = TTLCache(maxsize=100, ttl=3600)

PUBLIC_URL = "https://muzic-production-a4ca.up.railway.app"

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Referer': 'https://www.youtube.com/',
}

ydl_opts = {
    'format': 'bestaudio/best',
    'quiet': True,
    'no_warnings': True,
    'nocheckcertificate': True,
}

@app.route('/')
def home():
    return "Muzic API is running fast!"

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_stream(video_id):
    try:
        # Önce cache'e bak
        if video_id not in url_cache:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                url_cache[video_id] = {
                    'stream_url': info['url'],
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0)
                }

        data = url_cache[video_id]
        return jsonify({
            'success': True,
            'stream_url': f"{PUBLIC_URL}/api/listen/{video_id}",
            'title': data['title'],
            'duration': data['duration'],
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/listen/<video_id>')
def listen(video_id):
    try:
        # Cache'den doğrudan al (yt-dlp'yi tekrar çalıştırma!)
        if video_id in url_cache:
            stream_url = url_cache[video_id]['stream_url']
        else:
            # Cache'de yoksa mecbur çek
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info['url']
                url_cache[video_id] = {'stream_url': stream_url}

        range_header = request.headers.get('Range', None)
        headers = HEADERS.copy()
        if range_header:
            headers['Range'] = range_header

        resp = requests.get(stream_url, stream=True, headers=headers, timeout=15)

        rv = Response(
            stream_with_context(resp.iter_content(chunk_size=1024*32)),
            content_type=resp.headers.get('Content-Type', 'audio/mpeg'),
            status=resp.status_code
        )
        rv.headers.add('Accept-Ranges', 'bytes')
        if 'Content-Range' in resp.headers:
            rv.headers.add('Content-Range', resp.headers['Content-Range'])
        return rv
    except Exception as e:
        return str(e), 500

@app.route('/api/search', methods=['POST'])
def search():
    try:
        data = request.get_json()
        query = data.get('query', '')
        with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True}) as ydl:
            info = ydl.extract_info(f'ytsearch5:{query}', download=False)
            results = []
            if 'entries' in info:
                for entry in info['entries']:
                    results.append({'video_id': entry.get('id'), 'title': entry.get('title'), 'uploader': entry.get('uploader', 'Unknown'), 'duration': entry.get('duration', 0)})
            return jsonify({'success': True, 'results': results}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
