import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from './firebase';
import { Shield, ShieldOff, Search } from 'lucide-react';

export default function UsersManager() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [userToDemote, setUserToDemote] = useState(null);
  const [demoteError, setDemoteError] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, []);

  async function fetchUsers() {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const fetchedUsers = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setUsers(fetchedUsers);
    } catch (error) {
      console.error("Error fetching users: ", error);
    } finally {
      setLoading(false);
    }
  }

  const toggleAdminRole = async (userId, currentRole) => {
    const isDemoting = currentRole === 'admin';
    
    if (isDemoting) {
      // Show custom modal instead of window.confirm
      setUserToDemote(userId);
      return;
    }
    
    // If promoting, do it directly
    executeRoleChange(userId, 'user', 'admin');
  };

  const executeRoleChange = async (userId, currentRole, forceNewRole = null) => {
    const newRole = forceNewRole || (currentRole === 'admin' ? 'user' : 'admin');
    setDemoteError('');
    setIsProcessing(true);
    
    try {
      await updateDoc(doc(db, 'users', userId), { role: newRole });
      setUsers(users.map(u => u.id === userId ? { ...u, role: newRole } : u));
      setUserToDemote(null); // Close modal if open
    } catch (error) {
      console.error("Role update error:", error);
      setDemoteError(error.message || 'Permission denied or network error.');
    } finally {
      setIsProcessing(false);
    }
  };

  const filteredUsers = users.filter(u => 
    u.email?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    (u.display_name || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  const viewDetails = (user) => {
    setSelectedUser(user);
  };

  const closeDetails = () => {
    setSelectedUser(null);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-slate-800">Users Manager</h2>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 bg-slate-50 flex justify-between items-center">
          <div className="relative w-64">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Search className="h-4 w-4 text-slate-400" />
            </div>
            <input
              type="text"
              className="focus:ring-blue-500 focus:border-blue-500 block w-full pl-9 sm:text-sm border-slate-300 rounded-md py-2 border"
              placeholder="Search by email or name..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="text-sm text-slate-500">Total: {filteredUsers.length} users</div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">User Info</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Role</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">Preferences</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-slate-200">
              {loading ? (
                <tr><td colSpan="4" className="px-6 py-4 text-center text-slate-500">Loading users...</td></tr>
              ) : filteredUsers.length === 0 ? (
                <tr><td colSpan="4" className="px-6 py-4 text-center text-slate-500">No users found.</td></tr>
              ) : (
                filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold overflow-hidden">
                          {user.profile_image ? (
                             <img src={user.profile_image} alt="" className="h-full w-full object-cover" />
                          ) : (
                             user.email?.[0].toUpperCase()
                          )}
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-slate-900">{user.display_name || 'No Name'}</div>
                          <div className="text-sm text-slate-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${user.role === 'admin' ? 'bg-indigo-100 text-indigo-800' : 'bg-slate-100 text-slate-800'}`}>
                        {user.role || 'user'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-500">
                      <div className="max-w-[200px] truncate">
                        {user.preferred_categories?.join(', ') || 'None'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button 
                        onClick={() => viewDetails(user)} 
                        className="inline-flex items-center px-3 py-1 rounded-md border text-xs font-medium transition-colors bg-white text-slate-700 border-slate-300 hover:bg-slate-50 mr-2"
                      >
                        View Details
                      </button>
                      <button 
                        onClick={() => toggleAdminRole(user.id, user.role)} 
                        className={`inline-flex items-center px-3 py-1 rounded-md border text-xs font-medium transition-colors ${
                          user.role === 'admin' 
                            ? 'bg-red-50 text-red-700 border-red-200 hover:bg-red-100' 
                            : 'bg-indigo-50 text-indigo-700 border-indigo-200 hover:bg-indigo-100'
                        }`}
                      >
                        {user.role === 'admin' ? (
                          <><ShieldOff className="w-3 h-3 mr-1" /> Remove Admin</>
                        ) : (
                          <><Shield className="w-3 h-3 mr-1" /> Make Admin</>
                        )}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {selectedUser && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-y-auto overflow-x-hidden p-4">
          <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity" onClick={closeDetails}></div>
          
          <div className="relative w-full max-w-md bg-white rounded-2xl shadow-2xl p-6 transform transition-all z-10">
            <div>
              <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 mb-4">
                <Shield className="h-6 w-6 text-blue-600" aria-hidden="true" />
              </div>
              <div className="text-center sm:mt-5">
                <h3 className="text-xl font-bold text-slate-900 mb-2">User Details</h3>
                <div className="mt-2 border-t border-slate-200 pt-4 text-left">
                  <p className="text-sm text-slate-600 mb-2"><strong>Name:</strong> {selectedUser.display_name || 'No Name'}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Email:</strong> {selectedUser.email}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>ID:</strong> {selectedUser.id}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Role:</strong> {selectedUser.role || 'user'}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Phone:</strong> {selectedUser.phone_number || 'N/A'}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Bio:</strong> {selectedUser.bio || 'N/A'}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Categories:</strong> {selectedUser.preferred_categories?.join(', ') || 'N/A'}</p>
                  <p className="text-sm text-slate-600 mb-2"><strong>Emergency Contact:</strong> {selectedUser.emergency_contact_name || 'N/A'} ({selectedUser.emergency_contact_phone || 'N/A'})</p>
                </div>
              </div>
            </div>
            <div className="mt-6">
              <button
                type="button"
                className="w-full inline-flex justify-center items-center rounded-xl border border-transparent shadow-sm px-4 py-2.5 bg-blue-600 text-sm font-semibold text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors"
                onClick={closeDetails}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Demotion Confirmation Modal */}
      {userToDemote && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-y-auto overflow-x-hidden p-4">
          {/* Backdrop */}
          <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity" onClick={() => !isProcessing && setUserToDemote(null)}></div>
          
          {/* Modal Content */}
          <div className="relative w-full max-w-md bg-white rounded-2xl shadow-2xl p-6 transform transition-all z-10">
            <div className="sm:flex sm:items-start mb-6">
              <div className="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
                <ShieldOff className="h-6 w-6 text-red-600" aria-hidden="true" />
              </div>
              <div className="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                <h3 className="text-xl font-bold text-slate-900">Remove Admin Privileges</h3>
                <div className="mt-2">
                  <p className="text-sm text-slate-600 leading-relaxed">
                    Are you sure you want to remove admin privileges from this user? They will lose access to this dashboard immediately.
                  </p>
                  {demoteError && (
                    <div className="mt-4 bg-red-50 text-red-700 p-3 rounded-lg text-sm border border-red-200 shadow-sm flex items-start gap-2">
                      <div className="font-bold shrink-0">Error:</div> 
                      <div>{demoteError}</div>
                    </div>
                  )}
                </div>
              </div>
            </div>
            
            <div className="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 mt-6">
              <button
                type="button"
                disabled={isProcessing}
                className="w-full sm:w-auto inline-flex justify-center items-center rounded-xl border border-slate-300 px-5 py-2.5 bg-white text-sm font-semibold text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-slate-200 transition-colors disabled:opacity-50"
                onClick={() => {
                  setUserToDemote(null);
                  setDemoteError('');
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isProcessing}
                className="w-full sm:w-auto inline-flex justify-center items-center rounded-xl border border-transparent px-5 py-2.5 bg-red-600 text-sm font-semibold text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors disabled:opacity-50"
                onClick={() => executeRoleChange(userToDemote, 'admin', 'user')}
              >
                {isProcessing ? (
                  <><span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span> Processing...</>
                ) : 'Remove Admin'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
