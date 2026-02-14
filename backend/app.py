from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests
from cachetools import TTLCache

app = Flask(__name__)
CORS(app)

# Linkleri 1 saat hafızada tutar
url_cache = TTLCache(maxsize=300, ttl=3600)

# YouTube kısıtlamalarını aşmak için başlıklar
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Referer': 'https://www.youtube.com/',
}

@app.route('/')
def home():
    return "Muzic API is Running!"

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_info(video_id):
    """Şarkı bilgilerini ve proxy linkini döner"""
    try:
        if video_id not in url_cache:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL({'format': 'bestaudio/best', 'quiet': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                url_cache[video_id] = {
                    'url': info['url'],
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0)
                }

        data = url_cache[video_id]
        # Kendi sunucumuz üzerinden dinleme linki
        proxy_url = f"{request.host_url.rstrip('/')}/api/listen/{video_id}"

        return jsonify({
            'success': True,
            'stream_url': proxy_url,
            'title': data['title'],
            'duration': data['duration']
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/listen/<video_id>')
def listen(video_id):
    """Müziği YouTube'dan alıp Range desteğiyle aktarır"""
    try:
        if video_id in url_cache:
            stream_url = url_cache[video_id]['url']
        else:
            url = f'https://www.youtube.com/watch?v={video_id}'
            with yt_dlp.YoutubeDL({'format': 'bestaudio/best', 'quiet': True}) as ydl:
                info = ydl.extract_info(url, download=False)
                stream_url = info['url']
                url_cache[video_id] = {'url': stream_url, 'title': info.get('title'), 'duration': info.get('duration')}

        # Telefonun istediği byte aralığını (Range) YouTube'a ilet
        headers = HEADERS.copy()
        if 'Range' in request.headers:
            headers['Range'] = request.headers['Range']

        resp = requests.get(stream_url, stream=True, headers=headers, timeout=10)

        # Gelen veriyi olduğu gibi telefona ilet
        rv = Response(
            stream_with_context(resp.iter_content(chunk_size=1024*128)),
            status=resp.status_code,
            content_type=resp.headers.get('Content-Type', 'audio/mpeg')
        )
        rv.headers.add('Accept-Ranges', 'bytes')
        if 'Content-Range' in resp.headers:
            rv.headers.add('Content-Range', resp.headers['Content-Range'])
        if 'Content-Length' in resp.headers:
            rv.headers.add('Content-Length', resp.headers['Content-Length'])

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
                    results.append({
                        'video_id': entry.get('id'),
                        'title': entry.get('title'),
                        'uploader': entry.get('uploader', 'Unknown'),
                        'duration': entry.get('duration', 0)
                    })
            return jsonify({'success': True, 'results': results})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, threaded=True)
