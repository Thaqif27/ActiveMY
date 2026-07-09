import React, { useEffect, useState, useRef } from 'react';
import { collection, query, getDocs, doc, deleteDoc, limit, addDoc } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from './firebase';
import { Calendar, MapPin, Trash2, Folder, Plus, X, Upload } from 'lucide-react';

export default function EventsManager() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  
  const [selectedCat, setSelectedCat] = useState('All');
  const [selectedStatus, setSelectedStatus] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  
  const [showAddModal, setShowAddModal] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [imageFile, setImageFile] = useState(null);
  const locationInputRef = useRef(null);
  const autocompleteRef = useRef(null);
  
  const [formData, setFormData] = useState({
    title: '', description: '', category: 'Running', date: '', location: '', imageUrl: '', price: 'Free', lat: '0', lng: '0', isVirtual: false
  });

  const categories = ['All', 'Running', 'Cycling', 'Hiking'];
  const statuses = ['All', 'Active', 'Past'];

  // Calculate today's date at midnight for comparison
  const today = new Date();
  today.setHours(0,0,0,0);

  useEffect(() => {
    fetchEvents();
  }, []);

  // Initialize Google Maps Autocomplete
  useEffect(() => {
    let checkInterval;
    
    const initAutocomplete = () => {
      if (showAddModal && locationInputRef.current && window.google) {
        autocompleteRef.current = new window.google.maps.places.Autocomplete(locationInputRef.current, {
          fields: ["formatted_address", "geometry", "name"],
        });

        autocompleteRef.current.addListener("place_changed", () => {
          const place = autocompleteRef.current.getPlace();
          if (place.geometry && place.geometry.location) {
            setFormData(prev => ({
              ...prev,
              location: place.formatted_address || place.name,
              lat: place.geometry.location.lat(),
              lng: place.geometry.location.lng()
            }));
          }
        });
        return true;
      }
      return false;
    };

    if (showAddModal) {
      if (!initAutocomplete()) {
        // If not ready, check every 500ms
        checkInterval = setInterval(() => {
          if (initAutocomplete()) {
            clearInterval(checkInterval);
          }
        }, 500);
      }
    }

    return () => {
      if (checkInterval) clearInterval(checkInterval);
    };
  }, [showAddModal]);

  async function fetchEvents() {
    setLoading(true);
    try {
      // Fetch up to 1000 events for management
      const q = query(collection(db, 'events'), limit(1000));
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

  const handleAddSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title || !formData.date || !formData.location) {
      alert("Title, Date, and Location are required.");
      return;
    }
    
    setIsSaving(true);
    try {
      let finalImageUrl = formData.imageUrl;
      
      if (imageFile) {
        const imageRef = ref(storage, `event_images/${Date.now()}_${imageFile.name}`);
        const snapshot = await uploadBytes(imageRef, imageFile);
        finalImageUrl = await getDownloadURL(snapshot.ref);
      }
      
      const eventData = {
        title: formData.title,
        description: formData.description,
        category: formData.category,
        date: new Date(formData.date),
        location: formData.location,
        lat: parseFloat(formData.lat) || 0.0,
        lng: parseFloat(formData.lng) || 0.0,
        source: "Admin",
        original_url: "",
        image_url: finalImageUrl,
        price: formData.price,
        scraped_at: new Date(),
        is_active: true,
        is_virtual: formData.isVirtual
      };
      await addDoc(collection(db, 'events'), eventData);
      alert("Event added successfully!");
      setShowAddModal(false);
      setImageFile(null);
      setFormData({
        title: '', description: '', category: 'Running', date: '', location: '', imageUrl: '', price: 'Free', lat: '0', lng: '0', isVirtual: false
      });
      fetchEvents();
    } catch (error) {
      console.error("Error adding event: ", error);
      alert("Failed to add event.");
    } finally {
      setIsSaving(false);
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
    } else {
      matchesCat = (e.category || '').toLowerCase() === selectedCat.toLowerCase();
    }
    
    const matchesStatus = selectedStatus === 'All' || stat.toLowerCase() === selectedStatus.toLowerCase();
    
    const matchesSearch = searchQuery === '' || (e.title || '').toLowerCase().includes(searchQuery.toLowerCase());
    
    return matchesCat && matchesStatus && matchesSearch;
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
      <div className="mb-8 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="text-2xl font-bold text-slate-800 mb-2">Manage Aggregated Events</h2>
          <p className="text-slate-500">Welcome back, manage your system here. Events are sorted by their event date.</p>
        </div>
        <button 
          onClick={() => setShowAddModal(true)}
          className="bg-blue-600 hover:bg-blue-700 text-white px-5 py-2.5 rounded-lg font-medium flex items-center shadow-sm transition-colors shrink-0"
        >
          <Plus className="w-5 h-5 mr-2" />
          Add Event
        </button>
      </div>

      <div className="mb-6">
        <input 
          type="text" 
          placeholder="Search events by title..." 
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full md:w-1/2 px-4 py-2 border border-slate-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
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

      {/* Add Event Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
            <div className="flex justify-between items-center p-6 border-b border-slate-100">
              <h3 className="text-xl font-bold text-slate-800">Add New Event</h3>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto">
              <form id="add-event-form" onSubmit={handleAddSubmit} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-slate-700 mb-1">Event Title *</label>
                    <input type="text" required value={formData.title} onChange={e => setFormData({...formData, title: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-slate-700 mb-1">Description</label>
                    <textarea rows="3" value={formData.description} onChange={e => setFormData({...formData, description: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500"></textarea>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Category</label>
                    <select value={formData.category} onChange={e => setFormData({...formData, category: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500">
                      {categories.filter(c => c !== 'All').map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Event Date *</label>
                    <input type="datetime-local" required value={formData.date} onChange={e => setFormData({...formData, date: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-slate-700 mb-1">Location *</label>
                    <input 
                      type="text" 
                      required 
                      ref={locationInputRef}
                      value={formData.location} 
                      onChange={e => setFormData({...formData, location: e.target.value})} 
                      className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" 
                      placeholder="Search for a place..."
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Latitude</label>
                    <input type="number" step="any" value={formData.lat} onChange={e => setFormData({...formData, lat: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Longitude</label>
                    <input type="number" step="any" value={formData.lng} onChange={e => setFormData({...formData, lng: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-slate-700 mb-1">Upload Event Image</label>
                    <input 
                      type="file" 
                      accept="image/*"
                      onChange={e => {
                        if (e.target.files[0]) {
                          setImageFile(e.target.files[0]);
                          setFormData({...formData, imageUrl: ''});
                        }
                      }} 
                      className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500 text-sm" 
                    />
                    <div className="text-xs text-slate-500 mt-1">Or provide an image URL below if you don't have a file.</div>
                  </div>
                  
                  <div className="col-span-2">
                    <label className="block text-sm font-medium text-slate-700 mb-1">Image URL (Optional)</label>
                    <input type="url" disabled={!!imageFile} value={formData.imageUrl} onChange={e => setFormData({...formData, imageUrl: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:bg-slate-100" placeholder="https://..." />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Price</label>
                    <input type="text" value={formData.price} onChange={e => setFormData({...formData, price: e.target.value})} className="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                  </div>
                  
                  <div className="flex items-center mt-6">
                    <input type="checkbox" id="isVirtual" checked={formData.isVirtual} onChange={e => setFormData({...formData, isVirtual: e.target.checked})} className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
                    <label htmlFor="isVirtual" className="ml-2 block text-sm text-slate-700">Virtual Event</label>
                  </div>
                </div>
              </form>
            </div>
            
            <div className="p-6 border-t border-slate-100 flex justify-end gap-3 bg-slate-50 rounded-b-xl">
              <button type="button" onClick={() => setShowAddModal(false)} className="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50">
                Cancel
              </button>
              <button type="submit" disabled={isSaving} form="add-event-form" className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:bg-blue-400 flex items-center">
                {isSaving ? 'Saving...' : 'Save Event'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
