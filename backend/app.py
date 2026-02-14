from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests
from cachetools import TTLCache

app = Flask(__name__)
CORS(app)

# Linkleri 1 saat hafızada tut
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
    return "Muzic API is running stable!"

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_stream(video_id):
    try:
        if video_id not in url_cache:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                url_cache[video_id] = {
                    'stream_url': info['url'],
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0)
                }

        return jsonify({
            'success': True,
            'stream_url': f"{PUBLIC_URL}/api/listen/{video_id}",
            'title': url_cache[video_id]['title'],
            'duration': url_cache[video_id]['duration'],
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/listen/<video_id>')
def listen(video_id):
    try:
        if video_id in url_cache:
            stream_url = url_cache[video_id]['stream_url']
        else:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info['url']
                url_cache[video_id] = {'stream_url': stream_url}

        # Telefonun istediği Range değerini al
        req_headers = {k: v for k, v in request.headers if k.lower() in ['range', 'user-agent']}
        req_headers.update(HEADERS)

        # YouTube'a bağlan
        resp = requests.get(stream_url, stream=True, headers=req_headers, timeout=20)

        # YouTube'un gönderdiği gerçek başlıkları (Content-Type, Length vb.) aktar
        rv_headers = {
            'Accept-Ranges': 'bytes',
            'Content-Type': resp.headers.get('Content-Type', 'audio/mpeg'),
            'Content-Length': resp.headers.get('Content-Length'),
            'Content-Range': resp.headers.get('Content-Range'),
            'Cache-Control': 'no-cache',
        }
        # None olan başlıkları temizle
        rv_headers = {k: v for k, v in rv_headers.items() if v is not None}

        return Response(
            stream_with_context(resp.iter_content(chunk_size=1024*64)),
            status=resp.status_code,
            headers=rv_headers
        )
    except Exception as e:
        return str(e), 500

# Arama ve Status aynı...
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
    except Exception as e: return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, threaded=True)
