import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, doc, deleteDoc, limit } from 'firebase/firestore';
import { db } from './firebase';
import { Calendar, MapPin, Trash2, Folder } from 'lucide-react';

export default function EventsManager() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  
  const [selectedCat, setSelectedCat] = useState('All');
  const [selectedStatus, setSelectedStatus] = useState('All');

  const categories = ['All', 'Running', 'Cycling', 'Hiking', 'Triathlon', 'Virtual'];
  const statuses = ['All', 'Active', 'Past'];

  // Calculate today's date at midnight for comparison
  const today = new Date();
  today.setHours(0,0,0,0);

  useEffect(() => {
    fetchEvents();
  }, []);

  async function fetchEvents() {
    setLoading(true);
    try {
      // Fetch up to 200 events for management
      const q = query(collection(db, 'events'), limit(200));
      const snapshot = await getDocs(q);
      const fetchedEvents = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      // Sort by date descending
      fetchedEvents.sort((a, b) => {
        const dateA = typeof a.date === 'object' && a.date?.toDate ? a.date.toDate() : new Date(a.date || 0);
        const dateB = typeof b.date === 'object' && b.date?.toDate ? b.date.toDate() : new Date(b.date || 0);
        return dateB - dateA;
      });

      setEvents(fetchedEvents);
    } catch (error) {
      console.error("Error fetching events: ", error);
    } finally {
      setLoading(false);
    }
  }

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this event?")) {
      try {
        await deleteDoc(doc(db, 'events', id));
        setEvents(events.filter(e => e.id !== id));
      } catch (error) {
        alert("Failed to delete event.");
      }
    }
  };

  const getEventStatus = (event) => {
    const eventDateObj = typeof event.date === 'object' && event.date?.toDate ? event.date.toDate() : new Date(event.date);
    if (eventDateObj < today) return 'Past';
    return event.status === 'pending' ? 'Pending' : 'Active';
  };

  const getEventDateString = (event) => {
    const eventDateObj = typeof event.date === 'object' && event.date?.toDate ? event.date.toDate() : new Date(event.date);
    return eventDateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  const filteredEvents = events.filter(e => {
    const stat = getEventStatus(e);
    
    let matchesCat = false;
    if (selectedCat === 'All') {
      matchesCat = true;
    } else if (selectedCat.toLowerCase() === 'virtual') {
      matchesCat = e.is_virtual === true || (e.category || '').toLowerCase() === 'virtual';
    } else {
      matchesCat = (e.category || '').toLowerCase() === selectedCat.toLowerCase();
    }
    
    const matchesStatus = selectedStatus === 'All' || stat.toLowerCase() === selectedStatus.toLowerCase();
    return matchesCat && matchesStatus;
  });

  const FilterButton = ({ label, selected, onClick, isBlue }) => (
    <button
      onClick={onClick}
      className={`px-4 py-1.5 rounded-md text-sm font-medium transition-all ${
        selected
          ? isBlue 
            ? 'bg-blue-100 border border-blue-500 text-blue-700 shadow-sm'
            : 'bg-blue-100 border border-blue-500 text-blue-700 shadow-sm'
          : 'border border-slate-300 text-slate-600 hover:bg-slate-50 bg-white'
      }`}
    >
      {selected && <span className="mr-1">✓</span>}
      {label}
    </button>
  );

  return (
    <div className="bg-slate-50 min-h-[calc(100vh-4rem)] p-2 text-slate-900">
      <div className="mb-8">
        <h2 className="text-2xl font-bold text-slate-800 mb-2">Manage Aggregated Events</h2>
        <p className="text-slate-500">Welcome back, manage your system here.</p>
      </div>

      <div className="space-y-4 mb-8">
        <div className="flex items-center space-x-4">
          <span className="text-sm font-bold w-20">Category:</span>
          <div className="flex flex-wrap gap-2">
            {categories.map(c => (
              <FilterButton 
                key={c} 
                label={c} 
                selected={selectedCat === c} 
                onClick={() => setSelectedCat(c)} 
                isBlue={true}
              />
            ))}
          </div>
        </div>
        
        <div className="flex items-center space-x-4">
          <span className="text-sm font-bold text-slate-700 w-20">Status:</span>
          <div className="flex flex-wrap gap-2">
            {statuses.map(s => (
              <FilterButton 
                key={s} 
                label={s} 
                selected={selectedStatus === s} 
                onClick={() => setSelectedStatus(s)} 
                isBlue={true}
              />
            ))}
          </div>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-20">
          <div className="text-slate-400 animate-pulse">Loading events...</div>
        </div>
      ) : filteredEvents.length === 0 ? (
        <div className="flex justify-center py-20 border border-slate-200 rounded-xl bg-white shadow-sm">
          <div className="text-slate-500">No events match the selected filters.</div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {filteredEvents.map(event => {
            const status = getEventStatus(event);
            const dateStr = getEventDateString(event);
            
            return (
              <div key={event.id} className="bg-white rounded-xl overflow-hidden border border-slate-200 flex flex-col shadow-sm transition-transform hover:-translate-y-1 hover:shadow-md">
                {/* Image Section */}
                <div className="relative h-48 bg-slate-100">
                  {event.image_url ? (
                    <img src={event.image_url} alt={event.title} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-slate-400">No Image</div>
                  )}
                  
                  {/* Badges */}
                  <div className="absolute top-4 left-4">
                    <span className={`px-2 py-1 text-xs font-bold rounded shadow-sm ${status === 'Past' ? 'bg-slate-500 text-white' : status === 'Active' ? 'bg-green-500 text-white' : 'bg-amber-500 text-white'}`}>
                      {status.toUpperCase()}
                    </span>
                  </div>
                  <div className="absolute top-4 right-4">
                    <span className="px-3 py-1 text-xs font-bold rounded-full bg-blue-600 text-white shadow-sm uppercase tracking-wider">
                      {event.category || 'EVENT'}
                    </span>
                  </div>
                </div>

                {/* Content Section */}
                <div className="p-5 flex-1 flex flex-col">
                  <h3 className="text-lg font-bold text-slate-900 mb-4 line-clamp-2 leading-tight">
                    {event.title}
                  </h3>
                  
                  <div className="space-y-2 mb-6 flex-1">
                    <div className="flex items-center text-sm text-slate-600">
                      <Calendar className="w-4 h-4 mr-2 text-slate-400" />
                      {dateStr}
                    </div>
                    <div className="flex items-start text-sm text-slate-600">
                      <MapPin className="w-4 h-4 mr-2 mt-0.5 text-slate-400 shrink-0" />
                      <span className="line-clamp-2">{typeof event.location === 'object' ? 'Location Object' : event.location}</span>
                    </div>
                  </div>

                  <div className="pt-4 border-t border-slate-100 flex justify-between items-center mt-auto">
                    <div className="flex items-center text-xs font-bold text-slate-500 uppercase">
                      <Folder className="w-4 h-4 mr-1.5 text-slate-400" />
                      {event.source || 'MANUAL'}
                    </div>
                    <button 
                      onClick={() => handleDelete(event.id)}
                      className="flex items-center px-3 py-1.5 text-xs font-medium rounded border border-red-200 text-red-600 hover:bg-red-50 transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5 mr-1.5" />
                      DELETE
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
