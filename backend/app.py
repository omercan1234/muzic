from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests
from cachetools import TTLCache

app = Flask(__name__)
CORS(app)

# Şarkı linklerini 1 saat hafızada tutar (Hız için kritik)
url_cache = TTLCache(maxsize=200, ttl=3600)

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
    return "Muzic API is running with high performance!"

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
    """Müziği YouTube'dan alıp telefona tüneller (Range desteğiyle)"""
    try:
        if video_id in url_cache:
            stream_url = url_cache[video_id]['stream_url']
        else:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info['url']
                url_cache[video_id] = {'stream_url': stream_url}

        # Range desteği: Android'in parça parça indirmesini sağlar
        req_headers = {k: v for k, v in request.headers if k.lower() in ['range']}
        req_headers.update(HEADERS)

        resp = requests.get(stream_url, stream=True, headers=req_headers, timeout=15)

        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        headers = [(name, value) for (name, value) in resp.headers.items()
                   if name.lower() not in excluded_headers]

        return Response(
            stream_with_context(resp.iter_content(chunk_size=1024*32)),
            status=resp.status_code,
            headers=headers,
            content_type=resp.headers.get('Content-Type', 'audio/mpeg')
        )
    except Exception as e:
        return str(e), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, threaded=True)
