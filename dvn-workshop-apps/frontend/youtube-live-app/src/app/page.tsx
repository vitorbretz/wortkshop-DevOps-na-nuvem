'use client';

import { useState } from 'react';
import Image from 'next/image';

interface Video {
  id: string;
  title: string;
  description: string;
  thumbnail: string;
  channelTitle: string;
  publishedAt: string;
}

export default function Home() {
  const [query, setQuery] = useState('');
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const searchVideos = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError('');
    
    try {
      const response = await fetch(`/api/youtube/search?q=${encodeURIComponent(query)}`);
      
      if (!response.ok) {
        throw new Error('Erro ao buscar vídeos');
      }
      
      const data = await response.json();
      setVideos(data.items || []);
    } catch (err) {
      setError('Erro ao buscar vídeos. Tente novamente.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-br from-red-50 to-pink-50 dark:from-gray-900 dark:to-gray-800 p-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold text-red-600 dark:text-red-400 mb-4">
            🎬 YouTube Live Search
          </h1>
          <p className="text-gray-600 dark:text-gray-300 text-lg">
            Busque e explore vídeos do YouTube
          </p>
        </div>

        <form onSubmit={searchVideos} className="mb-12">
          <div className="flex gap-4 max-w-3xl mx-auto">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Digite sua busca..."
              className="flex-1 px-6 py-4 rounded-full border-2 border-red-300 focus:border-red-500 focus:outline-none text-lg dark:bg-gray-800 dark:text-white dark:border-red-600"
            />
            <button
              type="submit"
              disabled={loading}
              className="px-8 py-4 bg-red-600 hover:bg-red-700 disabled:bg-gray-400 text-white font-semibold rounded-full transition-colors text-lg"
            >
              {loading ? '🔍 Buscando...' : '🔍 Buscar'}
            </button>
          </div>
        </form>

        {error && (
          <div className="max-w-3xl mx-auto mb-8 p-4 bg-red-100 dark:bg-red-900 border border-red-400 text-red-700 dark:text-red-200 rounded-lg">
            {error}
          </div>
        )}

        {videos.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {videos.map((video) => (
              <div
                key={video.id}
                className="bg-white dark:bg-gray-800 rounded-xl shadow-lg overflow-hidden hover:shadow-2xl transition-shadow"
              >
                <Image
                  src={video.thumbnail}
                  alt={video.title}
                  width={400}
                  height={192}
                  className="w-full h-48 object-cover"
                />
                <div className="p-4">
                  <h3 className="font-semibold text-lg mb-2 text-gray-800 dark:text-white line-clamp-2">
                    {video.title}
                  </h3>
                  <p className="text-sm text-gray-600 dark:text-gray-300 mb-2">
                    {video.channelTitle}
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-3">
                    {video.description}
                  </p>
                  <a
                    href={`https://www.youtube.com/watch?v=${video.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-4 inline-block px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm transition-colors"
                  >
                    ▶️ Assistir
                  </a>
                </div>
              </div>
            ))}
          </div>
        )}

        {!loading && videos.length === 0 && !error && (
          <div className="text-center text-gray-500 dark:text-gray-400 text-lg">
            Use o campo de busca acima para encontrar vídeos do YouTube
          </div>
        )}
      </div>
    </main>
  );
}
