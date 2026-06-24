import React, { useEffect, useState } from 'react';
import { collection, query, where, getDocs, doc, deleteDoc, updateDoc, orderBy, limit } from 'firebase/firestore';
import { db } from './firebase';
import { CheckCircle, Trash2, ExternalLink } from 'lucide-react';

export default function NewlyScrapedEvents() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchNewlyScrapedEvents();
  }, []);

  const timeAgo = (date) => {
    if (!date) return '';
    let seconds = Math.floor((new Date() - date) / 1000);
    if (seconds < 0) return "just now";
    
    let interval = seconds / 31536000;
    if (interval > 1) return Math.floor(interval) + " years ago";
    interval = seconds / 2592000;
    if (interval > 1) return Math.floor(interval) + " months ago";
    interval = seconds / 86400;
    if (interval > 1) return Math.floor(interval) + " days ago";
    interval = seconds / 3600;
    if (interval > 1) return Math.floor(interval) + " hours ago";
    interval = seconds / 60;
    if (interval > 1) return Math.floor(interval) + " minutes ago";
    return Math.floor(seconds) + " seconds ago";
  };

  async function fetchNewlyScrapedEvents() {
    setLoading(true);
    try {
      const q = query(
        collection(db, 'events'),
        orderBy('scraped_at', 'desc'),
        limit(50)
      );
      const snapshot = await getDocs(q);
      
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const fetchedEvents = [];
      snapshot.forEach(doc => {
        const data = doc.data();
        if (data.scraped_at) {
          const scrapedDate = data.scraped_at.toDate ? data.scraped_at.toDate() : new Date(data.scraped_at);
          if (scrapedDate >= yesterday) {
            fetchedEvents.push({ id: doc.id, ...data });
          }
        }
      });
      
      setEvents(fetchedEvents);
    } catch (error) {
      console.error("Error fetching newly scraped events: ", error);
    } finally {
      setLoading(false);
    }
  }

  const getEventDateString = (event) => {
    if (!event.date) return 'N/A';
    const eventDateObj = typeof event.date === 'object' && event.date?.toDate ? event.date.toDate() : new Date(event.date);
    return eventDateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this newly scraped event?")) {
      try {
        await deleteDoc(doc(db, 'events', id));
        setEvents(events.filter(e => e.id !== id));
      } catch (error) {
        alert("Failed to delete event.");
      }
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-slate-800 mb-6">Newly Scraped Events</h2>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Title</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Date & Location</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Source</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-slate-200">
              {loading ? (
                <tr><td colSpan="4" className="px-6 py-4 text-center text-slate-500">Loading pending events...</td></tr>
              ) : events.length === 0 ? (
                <tr><td colSpan="4" className="px-6 py-4 text-center text-slate-500">No events were scraped in the last 24 hours.</td></tr>
              ) : (
                events.map((event) => (
                  <tr key={event.id} className="hover:bg-slate-50">
                    <td className="px-6 py-4">
                      <div className="text-sm font-bold text-slate-900">{event.title}</div>
                      <div className="text-xs text-slate-500 mt-1 line-clamp-2">{event.description}</div>
                      <a href={event.sourceUrl || event.original_link} target="_blank" rel="noreferrer" className="text-xs text-blue-600 hover:underline mt-1 inline-flex items-center">
                        View Source <ExternalLink className="ml-1 h-3 w-3" />
                      </a>
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-500">
                      <div className="font-medium">{getEventDateString(event)}</div>
                      <div>{event.location}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">
                          {event.source}
                        </span>
                      </div>
                      <div className="mt-2 text-xs text-slate-500 italic">
                        Scraped {timeAgo(typeof event.scraped_at === 'object' && event.scraped_at?.toDate ? event.scraped_at.toDate() : new Date(event.scraped_at))}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button onClick={() => handleDelete(event.id)} className="text-red-600 hover:text-red-900 bg-red-50 px-3 py-1 rounded-md border border-red-200">
                        <Trash2 className="h-4 w-4 inline mr-1" /> Delete
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
