from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests

app = Flask(__name__)
CORS(app)

PUBLIC_URL = "https://muzic-production-a4ca.up.railway.app"

# YouTube kısıtlamalarını aşmak için başlıklar
CHROME_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com/'
}

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
        proxy_url = f"{PUBLIC_URL}/api/listen/{video_id}"
        url = f'https://www.youtube.com/watch?v={video_id}'
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            return jsonify({
                'success': True,
                'stream_url': proxy_url,
                'title': info.get('title', 'Unknown'),
                'duration': info.get('duration', 0),
            }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/listen/<video_id>')
def listen(video_id):
    """Müziği YouTube'dan alıp telefona tüneller (Headers eklenerek 403 çözüldü)"""
    try:
        url = f'https://www.youtube.com/watch?v={video_id}'
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            stream_url = info['url']

            # YouTube stream'ini indir ve anlık olarak telefona gönder
            # Headers eklendi: 403 engeli için kritik
            req = requests.get(stream_url, stream=True, headers=CHROME_HEADERS, timeout=30)

            # Sunucudan gelen stream'i doğrudan aktar
            return Response(
                stream_with_context(req.iter_content(chunk_size=1024*16)),
                content_type=req.headers.get('content-type', 'audio/mpeg'),
                headers={
                    'Accept-Ranges': 'bytes',
                    'Cache-Control': 'no-cache',
                }
            )
    except Exception as e:
        return str(e), 500

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
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
