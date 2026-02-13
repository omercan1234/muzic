from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
import yt_dlp
import os
import requests

app = Flask(__name__)
CORS(app)

# Railway URL - Başına https:// eklemeyi unutmayın
PUBLIC_URL = "https://muzic-production-a4ca.up.railway.app"

# YouTube'u kandırmak için en güncel tarayıcı başlıkları
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com/',
}

ydl_opts = {
    'format': 'bestaudio/best',
    'quiet': True,
    'no_warnings': True,
    'nocheckcertificate': True,
    'extract_flat': False,
}

@app.route('/')
def home():
    return "Muzic API is active and running on port 8080!"

@app.route('/api/music/<video_id>', methods=['GET'])
def get_music_stream(video_id):
    try:
        # Telefon artık bu linke gidecek
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
        print(f"Error in get_music_stream: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/listen/<video_id>')
def listen(video_id):
    """YouTube stream'ini Range desteğiyle aktarır (ExoPlayer hatasını çözer)"""
    try:
        url = f'https://www.youtube.com/watch?v={video_id}'
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            stream_url = info['url']

            # Range başlığını telefondan alıp YouTube'a ilet
            range_header = request.headers.get('Range', None)
            headers = HEADERS.copy()
            if range_header:
                headers['Range'] = range_header

            # YouTube'dan müzik parçasını çek
            resp = requests.get(stream_url, stream=True, headers=headers, timeout=20)

            # Gelen cevabı doğrudan telefona akıt
            rv = Response(
                stream_with_context(resp.iter_content(chunk_size=1024*32)),
                content_type=resp.headers.get('Content-Type', 'audio/mpeg'),
                status=resp.status_code
            )
            rv.headers.add('Accept-Ranges', 'bytes')
            if 'Content-Range' in resp.headers:
                rv.headers.add('Content-Range', resp.headers['Content-Range'])
            if 'Content-Length' in resp.headers:
                rv.headers.add('Content-Length', resp.headers['Content-Length'])

            return rv
    except Exception as e:
        print(f"Streaming error for {video_id}: {e}")
        return str(e), 500

# Arama endpoint'i (Search)
@app.route('/api/search', methods=['POST'])
def search():
    try:
        data = request.get_json()
        query = data.get('query', '')
        if not query: return jsonify({'error': 'Empty query'}), 400

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
