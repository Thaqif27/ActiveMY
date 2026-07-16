import React, { useEffect, useState } from 'react';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { db } from './firebase';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { MapPin } from 'lucide-react';

// Fix for default Leaflet icon paths in React
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

export default function MapScreen() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  // Center of Malaysia
  const centerMalaysia = [4.2105, 101.9758];

  useEffect(() => {
    async function fetchEvents() {
      try {
        const q = query(collection(db, 'events'), where('is_active', '==', true));
        const snapshot = await getDocs(q);
        const validEvents = [];

        snapshot.forEach(doc => {
          const data = doc.data();
          if (!data.is_virtual && data.lat !== undefined && data.lng !== undefined && data.lat !== 0 && data.lng !== 0) {
            validEvents.push({ id: doc.id, ...data });
          }
        });

        // Add a slight offset to overlapping markers so they fan out and don't hide each other
        const locationCounts = {};
        const eventsWithOffset = validEvents.map(event => {
          const key = `${event.lat},${event.lng}`;
          if (!locationCounts[key]) {
            locationCounts[key] = 0;
          }
          const count = locationCounts[key]++;
          
          let latOffset = 0;
          let lngOffset = 0;
          
          if (count > 0) {
            // Radius expands slightly with more items
            const radius = 0.00015 * Math.ceil(count / 8); 
            const angle = (count * 45) * (Math.PI / 180);
            latOffset = radius * Math.cos(angle);
            lngOffset = radius * Math.sin(angle);
          }
          
          return {
            ...event,
            displayLat: event.lat + latOffset,
            displayLng: event.lng + lngOffset
          };
        });

        setEvents(eventsWithOffset);
      } catch (e) {
        console.error("Error fetching map events:", e);
      } finally {
        setLoading(false);
      }
    }
    fetchEvents();
  }, []);

  const getCategoryIcon = (category) => {
    const cat = (category || '').toLowerCase();
    let svg = '';
    let color = 'bg-slate-500';
    
    if (cat.includes('run')) { 
      color = 'bg-red-500';
      svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5"><path d="M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9L7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 7.8V13h2V9.6l1.8-.7"/></svg>`;
    }
    else if (cat.includes('cycl') || cat.includes('ride')) { 
      color = 'bg-blue-500';
      svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5"><path d="M15.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM5 12c-2.8 0-5 2.2-5 5s2.2 5 5 5 5-2.2 5-5-2.2-5-5-5zm0 8.5c-1.9 0-3.5-1.6-3.5-3.5s1.6-3.5 3.5-3.5 3.5 1.6 3.5 3.5-1.6 3.5-3.5 3.5zm14-8.5c-2.8 0-5 2.2-5 5s2.2 5 5 5 5-2.2 5-5-2.2-5-5-5zm0 8.5c-1.9 0-3.5-1.6-3.5-3.5s1.6-3.5 3.5-3.5 3.5 1.6 3.5 3.5-1.6 3.5-3.5 3.5zM10.5 12l-1.8-6H5V4.5h4.8l2 6.5L15 9V4.5h1.5v5.5l-3.8 2.5 1.5 5h-1.6l-1.1-3.6L10.5 12z"/></svg>`;
    }
    else if (cat.includes('hik') || cat.includes('climb')) { 
      color = 'bg-green-500';
      svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5"><path d="M14 6l-5 8h10l-5-8zM7 11l-4 6h8l-4-6z"/></svg>`;
    }
    else { 
      color = 'bg-purple-500';
      svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>`;
    }
    
    return L.divIcon({
      className: 'custom-leaflet-icon',
      html: `<div class="flex items-center justify-center w-8 h-8 rounded-full ${color} text-white shadow-md border-[2.5px] border-white drop-shadow-sm">${svg}</div>`,
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -16]
    });
  };

  return (
    <div className="flex flex-col h-[calc(100vh-8rem)] relative">
      <div className="flex justify-between items-center mb-6 z-10 relative">
        <h2 className="text-2xl font-bold text-slate-800">Geocoding Monitor</h2>
        <div className="bg-white px-4 py-2 rounded-full shadow-sm border border-slate-200 text-sm font-medium text-slate-600 flex items-center">
          <MapPin className="w-4 h-4 mr-2 text-blue-500" />
          {loading ? 'Loading events...' : `${events.length} Physical Events Mapped`}
        </div>
      </div>

      <div className="flex-1 bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden relative z-0">
        <MapContainer center={centerMalaysia} zoom={6} scrollWheelZoom={true} className="w-full h-full">
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {events.map(event => (
            <Marker key={event.id} position={[event.displayLat, event.displayLng]} icon={getCategoryIcon(event.category)}>
              <Popup>
                <div className="w-48">
                  {event.image_url && (
                    <img src={event.image_url} alt={event.title} className="w-full h-24 object-cover rounded-md mb-2" />
                  )}
                  <h3 className="font-bold text-sm text-slate-900 leading-tight">{event.title}</h3>
                  <p className="text-xs text-slate-500 mt-1">{event.location}</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}
