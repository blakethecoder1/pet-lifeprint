// Lifeprint - The City Remembers
// Premium NUI Application - Vanilla JavaScript

(function() {
    'use strict';

    // =========================================================================
    // State Management
    // =========================================================================

    const state = {
        visible: false,
        loading: true,
        player: null,
        memories: [],
        relationships: [],
        socialLinks: [],
        reputation: [],
        rumors: [],
        counters: {},
        tags: [],
        characterRead: null,
        config: null,
        selectedTarget: null,
        searchResults: [],
        currentSearchResultsId: null,
        activeFilter: 'all',
        peopleSearchQuery: '',
        // Admin state
        isAdmin: false,
        adminVisible: false,
        adminPlayer: null,
        adminPlayerData: null,
        adminActiveTab: 'data',
        // Settings state
        settingsVisible: false,
        // Photo state
        photoLoading: false,
        photoError: false
    };

    // =========================================================================
    // DOM Elements (initialized in init())
    // =========================================================================

    let elements = null;

    // =========================================================================
    // NUI Communication
    // =========================================================================

    const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'lifeprint';
    const isDebug = !window.GetParentResourceName;

    function nuiCallback(event, data) {
        if (isDebug) {
            console.log(`[Debug] NUI Callback: ${event}`, data);
            return;
        }

        try {
            fetch(`https://${resourceName}/${event}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data || {})
            }).catch(err => console.error('NUI Callback Error:', err));
        } catch (error) {
            console.error('NUI Callback Error:', error);
        }
    }

    // =========================================================================
    // Custom Confirmation Modal
    // =========================================================================

    let confirmResolve = null;

    function showConfirm(title, message) {
        return new Promise((resolve) => {
            confirmResolve = resolve;
            
            const modal = document.getElementById('confirm-modal');
            const titleEl = document.getElementById('confirm-title');
            const messageEl = document.getElementById('confirm-message');
            const okBtn = document.getElementById('confirm-ok');
            const cancelBtn = document.getElementById('confirm-cancel');
            const backdrop = modal ? modal.querySelector('.confirm-modal-backdrop') : null;
            
            if (!modal || !titleEl || !messageEl) {
                resolve(false);
                return;
            }
            
            titleEl.textContent = title || 'Confirm Action';
            messageEl.textContent = message || 'Are you sure you want to proceed?';
            
            modal.classList.remove('hidden');
            
            const handleOk = () => {
                modal.classList.add('hidden');
                const resolve = confirmResolve;
                cleanup();
                if (resolve) resolve(true);
            };

            const handleCancel = () => {
                modal.classList.add('hidden');
                const resolve = confirmResolve;
                cleanup();
                if (resolve) resolve(false);
            };
            
            const cleanup = () => {
                if (okBtn) okBtn.removeEventListener('click', handleOk);
                if (cancelBtn) cancelBtn.removeEventListener('click', handleCancel);
                if (backdrop) backdrop.removeEventListener('click', handleCancel);
                confirmResolve = null;
            };
            
            if (okBtn) okBtn.addEventListener('click', handleOk);
            if (cancelBtn) cancelBtn.addEventListener('click', handleCancel);
            if (backdrop) backdrop.addEventListener('click', handleCancel);
        });
    }

    // =========================================================================
    // Mock Data for Debug Mode
    // =========================================================================

    const mockData = {
        open: {
            player: { 
                identifier: 'CITIZEN-7X9K2M', 
                name: 'Marcus Chen',
                lastUpdated: Math.floor(Date.now() / 1000) - 3600
            },
            memories: [
                { 
                    id: 1, 
                    memory_type: 'encounter', 
                    description: 'First day in Los Santos. Stepped off the bus at Legion Square, took in the city skyline. A stranger bumped into me - didn\'t apologize.', 
                    location: 'Legion Square', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 604800 
                },
                { 
                    id: 2, 
                    memory_type: 'business', 
                    description: 'Got hired at Downtown Cab Co. The dispatcher, an older guy with a thick accent, showed me the ropes. Seems like a decent gig to start.', 
                    location: 'Downtown Cab Co.', 
                    visibility: 'public',
                    timestamp: Math.floor(Date.now() / 1000) - 518400 
                },
                { 
                    id: 3, 
                    memory_type: 'friendship', 
                    description: 'Met Sarah at the Pier. We talked for hours about why we came to this city. She\'s trying to start fresh too. Exchanged numbers.', 
                    location: 'Del Perro Pier', 
                    targetName: 'Sarah Wilson',
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 432000 
                },
                { 
                    id: 4, 
                    memory_type: 'crime', 
                    description: 'Witnessed an armed robbery at the 24/7 on Mirror Park. Called it in, but the cops took 20 minutes. Store owner was shaken but unhurt.', 
                    location: 'Mirror Park', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 259200 
                },
                { 
                    id: 5, 
                    memory_type: 'rescue', 
                    description: 'Car accident on the freeway. Blackout, then woke up in Pillbox. Dr. Morales said I was lucky - the EMS team got to me fast.', 
                    location: 'Pillbox Hill Medical Center', 
                    targetName: 'Dr. Morales',
                    visibility: 'public',
                    timestamp: Math.floor(Date.now() / 1000) - 86400 
                },
                { 
                    id: 6, 
                    memory_type: 'conflict', 
                    description: 'Got into a heated argument with some guy at the Vanilla Unicorn. He was hitting on someone who clearly wasn\'t interested. Bouncers threw us both out.', 
                    location: 'Vanilla Unicorn', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 43200 
                },
                { 
                    id: 7, 
                    memory_type: 'npc_vehicle_theft', 
                    title: 'Vehicle Stolen',
                    description: 'Stole a Sultan near Legion Square. Witnesses spotted the incident. The city remembers.', 
                    location: 'Legion Square', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 21600 
                },
                { 
                    id: 8, 
                    memory_type: 'gunshots', 
                    title: 'Shots Fired',
                    description: 'Fired shots near Grove Street. Witnesses reported the noise. The streets are watching.', 
                    location: 'Grove Street', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 10800 
                },
                { 
                    id: 9, 
                    memory_type: 'npc_kill', 
                    title: 'Witnessed Violence',
                    description: 'A violent incident occurred near the docks. The city won\'t forget what happened.', 
                    location: 'Terminal', 
                    visibility: 'private',
                    timestamp: Math.floor(Date.now() / 1000) - 3600 
                }
            ],
            relationships: [
                { 
                    target_identifier: 'SARAH-W892', 
                    targetName: 'Sarah Wilson', 
                    relationship_value: 65, 
                    relationship_type: 'close_friend',
                    last_interaction: Math.floor(Date.now() / 1000) - 86400,
                    notes: 'Met at the pier. Good listener.',
                    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
                    is_face_memory: 1,
                    memory_strength: 7
                },
                { 
                    target_identifier: 'MORALESM-123', 
                    targetName: 'Dr. Morales', 
                    relationship_value: 35, 
                    relationship_type: 'friend',
                    last_interaction: Math.floor(Date.now() / 1000) - 86400,
                    notes: 'Saved my life after the accident.',
                    photo: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Morales',
                    is_face_memory: 1,
                    memory_strength: 5
                },
                { 
                    target_identifier: 'JOHNSON-T456', 
                    targetName: 'Tony "The Shark"', 
                    relationship_value: -45, 
                    relationship_type: 'enemy',
                    last_interaction: Math.floor(Date.now() / 1000) - 43200,
                    notes: 'Vanilla Unicorn incident. Not someone to trust.',
                    is_face_memory: 0,
                    memory_strength: 3
                },
                { 
                    target_identifier: 'DISPATCH-001', 
                    targetName: 'Old Man Ray', 
                    relationship_value: 25, 
                    relationship_type: 'acquaintance',
                    last_interaction: Math.floor(Date.now() / 1000) - 172800,
                    notes: 'Cab company dispatcher. Gruff but fair.',
                    is_face_memory: 0,
                    memory_strength: 2
                }
            ],
            reputation: [
                { category: 'general', reputation_value: 22 },
                { category: 'criminal', reputation_value: -8 },
                { category: 'business', reputation_value: 15 },
                { category: 'law', reputation_value: 5 },
                { category: 'medical', reputation_value: 10 },
                { category: 'underground', reputation_value: -3 }
            ],
            counters: {
                arrests: 1,
                ems_visits: 1,
                crashes: 1,
                meetings: 5,
                helpful_actions: 1,
                suspicious_actions: 1,
                kills: 2,
                deaths: 3,
                npc_vehicle_thefts: 1,
                npc_assaults: 2,
                npc_kills: 1,
                gunshots_reported: 3,
                drug_deals: 1,
                injuries: 4,
                vehicle_hits: 1,
                gunshot_wounds: 2
            },
            tags: [
                { label: 'Well Connected', priority: 4, style: 'success', counter: 'meetings', value: 5 },
                { label: 'Has a Record', priority: 3, style: 'warning', counter: 'arrests', value: 1 },
                { label: 'Car Thief', priority: 3, style: 'warning', counter: 'npc_vehicle_thefts', value: 1 },
                { label: 'Trigger Happy', priority: 4, style: 'warning', counter: 'gunshots_reported', value: 3 },
                { label: 'Battered', priority: 2, style: 'warning', counter: 'injuries', value: 4 },
                { label: 'Bullet Magnet', priority: 3, style: 'danger', counter: 'gunshot_wounds', value: 2 }
            ],
            characterRead: 'Your Lifeprint suggests a well connected but has a record character with both redeeming qualities and concerning patterns. The city\'s opinion of you remains divided.',
            rumors: [
                { 
                    id: 1, 
                    rumor_type: 'secret', 
                    content: 'Word on the street is they\'ve got connections to someone high up in the city. Nobody knows who, but people notice when doors open for them.', 
                    sourceName: 'Street Whisper',
                    created_at: Math.floor(Date.now() / 1000) - 172800
                },
                { 
                    id: 2, 
                    rumor_type: 'hearsay', 
                    content: 'Heard they used to run with a crew back east before coming to Los Santos. Something went wrong - that\'s all anybody knows.', 
                    sourceName: 'Anonymous',
                    created_at: Math.floor(Date.now() / 1000) - 259200
                },
                { 
                    id: 3, 
                    rumor_type: 'achievement', 
                    content: 'Apparently they helped take down a robbery suspect last week. Some say they\'re a hero, others say they\'re a snitch.', 
                    targetName: 'Marcus Chen',
                    created_at: Math.floor(Date.now() / 1000) - 86400
                }
            ],
            config: {
                memoryTypes: [
                    { id: 'encounter', label: 'Encounter', icon: 'eye' },
                    { id: 'conflict', label: 'Conflict', icon: 'zap' },
                    { id: 'friendship', label: 'Friendship', icon: 'heart' },
                    { id: 'business', label: 'Business', icon: 'briefcase' },
                    { id: 'romantic', label: 'Romantic', icon: 'star' },
                    { id: 'betrayal', label: 'Betrayal', icon: 'skull' },
                    { id: 'rescue', label: 'Rescue', icon: 'shield' },
                    { id: 'crime', label: 'Crime', icon: 'lock' },
                    { id: 'other', label: 'Other', icon: 'file' }
                ],
                relationshipTypes: {
                    stranger: { min: 0, max: 10, label: 'Stranger', color: '#64748b' },
                    acquaintance: { min: 11, max: 30, label: 'Acquaintance', color: '#94a3b8' },
                    friend: { min: 31, max: 60, label: 'Friend', color: '#34d399' },
                    close_friend: { min: 61, max: 80, label: 'Close Friend', color: '#10b981' },
                    family: { min: 81, max: 100, label: 'Family', color: '#fbbf24' },
                    enemy: { min: -100, max: -31, label: 'Enemy', color: '#f87171' },
                    rival: { min: -30, max: -11, label: 'Rival', color: '#fca5a5' },
                    disliked: { min: -10, max: -1, label: 'Disliked', color: '#fecaca' }
                },
                reputationCategories: [
                    { id: 'general', label: 'General', color: '#a78bfa' },
                    { id: 'criminal', label: 'Criminal', color: '#f87171' },
                    { id: 'business', label: 'Business', color: '#34d399' },
                    { id: 'law', label: 'Law', color: '#60a5fa' },
                    { id: 'medical', label: 'Medical', color: '#ec4899' },
                    { id: 'underground', label: 'Underground', color: '#fbbf24' }
                ],
                reputationRanges: [
                    { min: -100, max: -75, label: 'Infamous', tier: -4 },
                    { min: -74, max: -50, label: 'Notorious', tier: -3 },
                    { min: -49, max: -25, label: 'Disreputable', tier: -2 },
                    { min: -24, max: -1, label: 'Dubious', tier: -1 },
                    { min: 0, max: 0, label: 'Unknown', tier: 0 },
                    { min: 1, max: 24, label: 'Known', tier: 1 },
                    { min: 25, max: 49, label: 'Respected', tier: 2 },
                    { min: 50, max: 74, label: 'Honored', tier: 3 },
                    { min: 75, max: 100, label: 'Legendary', tier: 4 }
                ],
                rumorTypes: [
                    { id: 'crime', label: 'Crime', icon: 'lock', color: '#f87171' },
                    { id: 'secret', label: 'Secret', icon: 'eyeOff', color: '#a78bfa' },
                    { id: 'affair', label: 'Personal', icon: 'heart', color: '#ec4899' },
                    { id: 'business', label: 'Business', icon: 'briefcase', color: '#34d399' },
                    { id: 'conflict', label: 'Conflict', icon: 'zap', color: '#fbbf24' },
                    { id: 'achievement', label: 'Achievement', icon: 'trophy', color: '#60a5fa' },
                    { id: 'scandal', label: 'Scandal', icon: 'alertTriangle', color: '#ef4444' },
                    { id: 'hearsay', label: 'Hearsay', icon: 'messageCircle', color: '#6b7280' }
                ],
                tagStyles: {
                    success: { bg: 'rgba(52, 211, 153, 0.15)', color: '#34d399', border: 'rgba(52, 211, 153, 0.3)' },
                    warning: { bg: 'rgba(251, 191, 36, 0.15)', color: '#fbbf24', border: 'rgba(251, 191, 36, 0.3)' },
                    danger: { bg: 'rgba(248, 113, 113, 0.15)', color: '#f87171', border: 'rgba(248, 113, 113, 0.3)' },
                    info: { bg: 'rgba(96, 165, 250, 0.15)', color: '#60a5fa', border: 'rgba(96, 165, 250, 0.3)' }
                }
            }
        }
    };

    // =========================================================================
    // SVG Icons
    // =========================================================================

    const icons = {
        eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
        zap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
        heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
        briefcase: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>',
        star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
        skull: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="10" r="7"/><circle cx="9" cy="9" r="1.5" fill="currentColor"/><circle cx="15" cy="9" r="1.5" fill="currentColor"/><path d="M9 14v2M12 14v3M15 14v2"/></svg>',
        shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
        lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
        file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>',
        location: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
        user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
        trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>',
        search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>',
        alertTriangle: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        messageCircle: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>',
        trophy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>',
        eyeOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
        check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>',
        x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
        info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
        document: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>',
        sparkles: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 3l1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5L12 3z"/><path d="M5 19l.5 1.5L7 21l-1.5.5L5 23l-.5-1.5L3 21l1.5-.5L5 19z"/><path d="M19 5l.5 1.5L21 7l-1.5.5L19 9l-.5-1.5L17 7l1.5-.5L19 5z"/></svg>'
    };

    // =========================================================================
    // Utility Functions
    // =========================================================================

    function formatDate(timestamp) {
        const date = new Date(timestamp * 1000);
        const now = new Date();
        const diff = now - date;
        const days = Math.floor(diff / (1000 * 60 * 60 * 24));
        const hours = Math.floor(diff / (1000 * 60 * 60));

        if (hours < 1) return 'Just now';
        if (hours < 24) return `${hours}h ago`;
        if (days === 1) return 'Yesterday';
        if (days < 7) return `${days} days ago`;
        if (days < 30) return `${Math.floor(days / 7)} weeks ago`;
        if (days < 365) return `${Math.floor(days / 30)} months ago`;
        return date.toLocaleDateString();
    }

    function formatRelativeTime(timestamp) {
        const date = new Date(timestamp * 1000);
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    function escapeHtml(value) {
        return String(value || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    // Generate initials from a name
    function getInitials(name) {
        if (!name) return '?';
        const words = name.trim().split(/\s+/);
        if (words.length >= 2) {
            return (words[0][0] + words[words.length - 1][0]).toUpperCase();
        }
        return (name[0] || '?').toUpperCase();
    }

    // Generate a deterministic background color based on name
    function getPhotoStyle(name) {
        if (!name) return 'background: linear-gradient(135deg, #6366f1, #8b5cf6);';
        
        // Generate a hash from the name for consistent colors
        let hash = 0;
        for (let i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        }
        
        // Predefined nice color pairs
        const colorPairs = [
            ['#6366f1', '#8b5cf6'], // Indigo to Violet
            ['#ec4899', '#f472b6'], // Pink
            ['#14b8a6', '#2dd4bf'], // Teal
            ['#f59e0b', '#fbbf24'], // Amber
            ['#ef4444', '#f87171'], // Red
            ['#3b82f6', '#60a5fa'], // Blue
            ['#10b981', '#34d399'], // Emerald
            ['#8b5cf6', '#a78bfa'], // Purple
            ['#06b6d4', '#22d3ee'], // Cyan
            ['#84cc16', '#a3e635'], // Lime
        ];
        
        const index = Math.abs(hash) % colorPairs.length;
        const [color1, color2] = colorPairs[index];
        
        return `background: linear-gradient(135deg, ${color1}, ${color2});`;
    }

    function getHeadshotImageSources(headshotTxd) {
        if (!headshotTxd || typeof headshotTxd !== 'string') return [];
        const txd = headshotTxd.trim();
        if (!txd) return [];
        return [
            `https://nui-img/${txd}/${txd}`,
            `nui://${txd}/${txd}`
        ];
    }

    function getImageSourceFromRelationship(rel) {
        if (!rel) return { primary: null, fallback: null, useHeadshot: false };

        const headshotSources = getHeadshotImageSources(rel.headshot_txd);
        const photoUrl = (rel.photo || rel.avatar_url || '').trim();

        if (headshotSources.length > 0) {
            return {
                primary: headshotSources[0],
                fallback: photoUrl || headshotSources[1] || null,
                useHeadshot: true
            };
        }

        return {
            primary: photoUrl || null,
            fallback: null,
            useHeadshot: false
        };
    }

    function getRelationshipType(value) {
        const types = state.config?.relationshipTypes || {};
        for (const [key, type] of Object.entries(types)) {
            if (value >= type.min && value <= type.max) {
                return { key, ...type };
            }
        }
        return { key: 'stranger', label: 'Stranger', color: '#64748b' };
    }

    function getReputationLabel(value) {
        const ranges = state.config?.reputationRanges || [];
        for (const range of ranges) {
            if (value >= range.min && value <= range.max) {
                return range.label;
            }
        }
        return 'Unknown';
    }

    function getMemoryIcon(type) {
        const iconMap = {
            encounter: 'eye',
            conflict: 'zap',
            friendship: 'heart',
            business: 'briefcase',
            romantic: 'star',
            betrayal: 'skull',
            rescue: 'shield',
            crime: 'lock',
            other: 'file'
        };
        return icons[iconMap[type]] || icons.file;
    }

    function getVisibilityBadge(visibility) {
        const badges = {
            private: { label: 'Private', class: 'visibility-private', icon: 'eyeOff' },
            public: { label: 'Public', class: 'visibility-public', icon: 'eye' },
            admin: { label: 'Admin', class: 'visibility-admin', icon: 'shield' }
        };
        const badge = badges[visibility] || badges.private;
        return `<span class="visibility-badge ${badge.class}">${icons[badge.icon]}${badge.label}</span>`;
    }

    function getRumorIcon(type) {
        const iconMap = {
            crime: 'lock',
            secret: 'eyeOff',
            affair: 'heart',
            business: 'briefcase',
            conflict: 'zap',
            achievement: 'trophy',
            scandal: 'alertTriangle',
            hearsay: 'messageCircle'
        };
        return icons[iconMap[type]] || icons.messageCircle;
    }

    function getCategoryLabel(category) {
        const categories = state.config?.reputationCategories || [];
        const cat = categories.find(c => c.id === category);
        return cat ? cat.label : category.charAt(0).toUpperCase() + category.slice(1);
    }

    // =========================================================================
    // Render Functions
    // =========================================================================

    function renderPlayer() {
        if (!elements || !state.player) return;
        
        if (elements.playerName) {
            elements.playerName.textContent = state.player.name;
        }
        if (elements.playerUpdated) {
            if (state.player.lastUpdated) {
                elements.playerUpdated.textContent = `Last updated: ${formatDate(state.player.lastUpdated)}`;
            } else {
                elements.playerUpdated.textContent = 'Last updated: Now';
            }
        }
        
        // Set initials in photo placeholder as fallback
        const initialsEl = document.getElementById('player-initials');
        if (initialsEl && state.player.name) {
            const nameParts = state.player.name.split(' ');
            let initials = '?';
            if (nameParts.length >= 2) {
                initials = (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase();
            } else if (nameParts.length === 1 && nameParts[0].length > 0) {
                initials = nameParts[0].substring(0, 2).toUpperCase();
            }
            initialsEl.textContent = initials;
        }
    }

    function renderMemories() {
        const container = elements.memoriesList;
        
        let filteredMemories = state.memories;
        if (state.activeFilter !== 'all') {
            filteredMemories = state.memories.filter(m => m.memory_type === state.activeFilter);
        }
        
        if (!filteredMemories || filteredMemories.length === 0) {
            const filterText = state.activeFilter !== 'all' ? ` for "${state.activeFilter}"` : '';
            const emptyIcon = state.activeFilter !== 'all' ? icons.search : icons.clock;
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">${emptyIcon}</div>
                    <h3>No Memories${filterText}</h3>
                    <p>${state.activeFilter !== 'all' 
                        ? 'Try selecting "All" to see your full timeline.' 
                        : 'Your timeline is empty. As you interact with the city, significant moments will be recorded here.'}
                    </p>
                </div>
            `;
            return;
        }

        container.innerHTML = filteredMemories.map((memory, index) => `
            <div class="memory-card" data-id="${memory.id}" style="animation-delay: ${index * 0.05}s">
                <div class="memory-header">
                    <div class="memory-header-badges">
                        <span class="memory-type-badge ${memory.memory_type}">
                            ${getMemoryIcon(memory.memory_type)}
                            ${memory.memory_type.charAt(0).toUpperCase() + memory.memory_type.slice(1)}
                        </span>
                        ${getVisibilityBadge(memory.visibility || 'private')}
                    </div>
                    <span class="memory-date">${formatDate(memory.timestamp)}</span>
                </div>
                ${memory.title ? `<h4 class="memory-title">${memory.title}</h4>` : ''}
                <p class="memory-description">${memory.description}</p>
                <div class="memory-footer">
                    ${memory.location ? `
                        <span class="memory-location">
                            ${icons.location}
                            ${memory.location}
                        </span>
                    ` : '<span></span>'}
                    <div style="display: flex; align-items: center; gap: 8px;">
                        ${memory.targetName ? `
                            <span class="memory-target">
                                ${icons.user}
                                ${memory.targetName}
                            </span>
                        ` : ''}
                        <button class="memory-delete" data-id="${memory.id}" title="Delete memory">
                            ${icons.trash}
                        </button>
                    </div>
                </div>
            </div>
        `).join('');

        // Attach delete handlers
        container.querySelectorAll('.memory-delete').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                deleteMemory(parseInt(btn.dataset.id));
            });
        });
    }

    // Track which relationship is being edited
    let editingRelationshipId = null;

    function renderRelationships() {
        const container = elements.relationshipsList;
        
        let filtered = state.relationships;
        if (state.peopleSearchQuery) {
            const query = state.peopleSearchQuery.toLowerCase();
            filtered = state.relationships.filter(r => 
                ((r.displayName || r.display_alias || r.targetName || '').toLowerCase().includes(query))
            );
        }
        
        if (!filtered || filtered.length === 0) {
            const searchMsg = state.peopleSearchQuery ? ' matching your search' : '';
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">${icons.user}</div>
                    <h3>No People${searchMsg}</h3>
                    <p>${state.peopleSearchQuery 
                        ? 'Try a different name or clear your search.' 
                        : 'You haven\'t formed any connections yet. Meet people in the city and they\'ll appear here.'}
                    </p>
                </div>
            `;
            return;
        }

        container.innerHTML = filtered.map((rel, index) => {
            const displayName = rel.displayName || rel.display_alias || rel.targetName;
            const type = getRelationshipType(rel.relationship_value);
            const percentage = Math.abs(rel.relationship_value);
            const barClass = rel.relationship_value > 0 ? 'positive' : rel.relationship_value < 0 ? 'negative' : 'neutral';
            const scoreClass = rel.relationship_value > 0 ? 'positive' : rel.relationship_value < 0 ? 'negative' : 'neutral';
            const isEditing = editingRelationshipId === rel.target_identifier;
            const noteText = rel.notes || '';
            const isFaceMemory = rel.is_face_memory === 1 || rel.is_face_memory === true;
            const firstLocation = rel.first_location || '';
            const firstMet = rel.first_met ? formatDate(rel.first_met) : '';
            const historyItems = Array.isArray(rel.history) ? rel.history.slice(0, 3) : [];
            
            // Photo handling - prioritize: headshot texture > photo URL > initials
            const imageSources = getImageSourceFromRelationship(rel);
            const initials = getInitials(displayName);
            const photoStyle = getPhotoStyle(displayName);
            const finalImgSrc = imageSources.primary;
            const fallbackImgSrc = imageSources.fallback;
            const useHeadshot = imageSources.useHeadshot;
            
            // Debug log photo data
            console.log(`[Lifeprint] Relationship ${displayName}: headshot=${rel.headshot_txd || 'none'}, photo=${rel.photo || rel.avatar_url || 'none'}, final=${finalImgSrc || 'initials'}`);
            
            return `
                <div class="relationship-card ${isFaceMemory ? 'face-memory-card' : ''}" data-target="${rel.target_identifier}" style="animation-delay: ${index * 0.05}s">
                    <div class="relationship-header">
                        <div class="relationship-avatar" style="${finalImgSrc ? '' : photoStyle}">
                            ${finalImgSrc 
                                ? `<img src="${finalImgSrc}" data-fallback-src="${fallbackImgSrc || ''}" alt="${displayName}" class="relationship-avatar-img${useHeadshot ? ' headshot-texture' : ''}" onerror="if(this.dataset.fallbackSrc && this.src!==this.dataset.fallbackSrc){console.warn('[Lifeprint] Primary image failed, trying fallback:', this.dataset.fallbackSrc);this.src=this.dataset.fallbackSrc;this.dataset.fallbackSrc='';return;}console.error('[Lifeprint] Image failed to load:', this.src);this.style.display='none';this.nextElementSibling.style.display='flex';" /><div class="relationship-avatar-fallback" style="display:none;${photoStyle}">${initials}</div>`
                                : `<span class="relationship-avatar-initials">${initials}</span>`
                            }
                        </div>
                        <div class="relationship-info">
                            <h4>${displayName}</h4>
                            ${(rel.display_alias && rel.targetName && rel.display_alias !== rel.targetName) ? `<span class="relationship-alias">Legal: ${escapeHtml(rel.targetName)}</span>` : ''}
                            <div class="relationship-badges">
                                <span class="relationship-badge" style="background: ${type.color}20; color: ${type.color};">${type.label}</span>
                                ${isFaceMemory ? `<span class="face-memory-badge" title="You remembered this face">${icons.eye} Face Memory</span>` : ''}
                            </div>
                        </div>
                        <span class="relationship-score ${scoreClass}">${rel.relationship_value > 0 ? '+' : ''}${rel.relationship_value}</span>
                    </div>
                    ${isFaceMemory ? `
                        <div class="face-memory-info">
                            ${noteText ? `<div class="face-memory-note"><span class="face-memory-label">Note:</span> "${noteText}"</div>` : ''}
                            ${firstLocation ? `<div class="face-memory-location"><span class="face-memory-label">First met:</span> ${firstLocation}</div>` : ''}
                            ${firstMet ? `<div class="face-memory-date"><span class="face-memory-label">Date:</span> ${firstMet}</div>` : ''}
                        </div>
                    ` : `
                        <div class="relationship-bar-container">
                            <div class="relationship-bar-bg">
                                <div class="relationship-bar-fill ${barClass}" style="width: ${percentage}%;"></div>
                            </div>
                        </div>
                    `}
                    ${historyItems.length > 0 ? `
                        <div class="relationship-history">
                            ${historyItems.map((item) => `<div class="relationship-history-item"><span>${escapeHtml(item.summary || 'Updated')}</span><span>${escapeHtml(item.createdAt || '')}</span></div>`).join('')}
                        </div>
                    ` : ''}
                    <div class="relationship-footer">
                        <span class="relationship-last-seen">
                            ${icons.clock}
                            ${rel.last_interaction ? formatDate(rel.last_interaction) : 'Unknown'}
                        </span>
                        ${isEditing ? `
                            <div class="relationship-note-edit">
                                <input type="text" class="relationship-note-input" value="${noteText.replace(/"/g, '&quot;')}" placeholder="Add a private note..." maxlength="200">
                                <button class="relationship-note-save" data-target="${rel.target_identifier}" title="Save">
                                    ${icons.check}
                                </button>
                                <button class="relationship-note-cancel" title="Cancel">
                                    ${icons.x}
                                </button>
                            </div>
                        ` : `
                            <div class="relationship-note-display">
                                ${!isFaceMemory && noteText ? `<span class="relationship-notes">"${noteText}"</span>` : !isFaceMemory ? '<span class="relationship-notes-empty">Add note</span>' : ''}
                                <button class="relationship-alias-btn" data-target="${rel.target_identifier}" data-current-alias="${escapeHtml(rel.display_alias || '')}" data-target-name="${escapeHtml(rel.targetName || '')}" title="Set alias">Alias</button>
                                <button class="relationship-note-edit-btn" data-target="${rel.target_identifier}" title="Edit note">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                        <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                                        <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                                    </svg>
                                </button>
                            </div>
                        `}
                    </div>
                </div>
            `;
        }).join('');

        // Attach edit button handlers
        container.querySelectorAll('.relationship-note-edit-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                editingRelationshipId = btn.dataset.target;
                renderRelationships();
                // Focus the input after render
                const input = container.querySelector('.relationship-note-input');
                if (input) {
                    input.focus();
                    input.select();
                }
            });
        });

        // Attach save button handlers
        container.querySelectorAll('.relationship-note-save').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const targetIdentifier = btn.dataset.target;
                const input = btn.parentElement.querySelector('.relationship-note-input');
                const note = input ? input.value.trim() : '';
                saveRelationshipNote(targetIdentifier, note);
            });
        });

        // Attach cancel button handlers
        container.querySelectorAll('.relationship-note-cancel').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                editingRelationshipId = null;
                renderRelationships();
            });
        });

        // Handle Enter key in note input
        container.querySelectorAll('.relationship-note-input').forEach(input => {
            input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    const targetIdentifier = input.parentElement.querySelector('.relationship-note-save').dataset.target;
                    saveRelationshipNote(targetIdentifier, input.value.trim());
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    editingRelationshipId = null;
                    renderRelationships();
                }
            });
        });

        container.querySelectorAll('.relationship-alias-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const targetIdentifier = btn.dataset.target;
                const currentAlias = btn.dataset.currentAlias || '';
                const targetName = btn.dataset.targetName || 'this person';
                const alias = window.prompt(`Set alias for ${targetName} (leave empty to clear):`, currentAlias);
                if (alias !== null) {
                    saveRelationshipAlias(targetIdentifier, alias.trim());
                }
            });
        });
    }

    function saveRelationshipNote(targetIdentifier, note) {
        nuiCallback('saveRelationshipNote', {
            targetIdentifier: targetIdentifier,
            notes: note
        });

        // Update local state optimistically
        const rel = state.relationships.find(r => r.target_identifier === targetIdentifier);
        if (rel) {
            rel.notes = note;
        }

        editingRelationshipId = null;
        renderRelationships();
        showToast('Note saved', 'success');
    }

    function saveRelationshipAlias(targetIdentifier, alias) {
        nuiCallback('saveRelationshipAlias', {
            targetIdentifier: targetIdentifier,
            alias: alias
        });

        const rel = state.relationships.find(r => r.target_identifier === targetIdentifier);
        if (rel) {
            rel.display_alias = alias || null;
            rel.displayName = alias || rel.targetName;
        }

        renderRelationships();
        showToast(alias ? 'Alias saved' : 'Alias cleared', 'success');
    }

    function renderSocialLinks() {
        if (!elements.socialLinksList) return;

        const links = Array.isArray(state.socialLinks) ? state.socialLinks : [];

        if (links.length === 0) {
            elements.socialLinksList.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">${icons.user}</div>
                    <h3>No frequent connections yet</h3>
                    <p>Spend more time near other players to build social patterns.</p>
                </div>
            `;
            if (elements.socialWebGraph) elements.socialWebGraph.innerHTML = '';
            return;
        }

        const topLinks = links.slice(0, 8);
        const maxSeenCount = Math.max(...topLinks.map((link) => Number(link.seenCount) || 0), 1);

        elements.socialLinksList.innerHTML = topLinks.map((link) => {
            const name = link.targetName || link.targetIdentifier || 'Unknown';
            const seenCount = Number(link.seenCount) || 0;
            const strength = Math.max(1, Math.min(4, Math.ceil((seenCount / maxSeenCount) * 4)));

            return `
                <div class="social-link-card">
                    <div class="social-link-avatar">${getInitials(name)}</div>
                    <div class="social-link-info">
                        <div class="social-link-name">${escapeHtml(name)}</div>
                        <div class="social-link-meta">
                            <span class="social-link-count">Seen ${seenCount}x</span>
                            <span class="social-link-time">Last: ${escapeHtml(link.lastSeen || 'unknown')}</span>
                        </div>
                    </div>
                    <div class="social-link-strength">
                        <div class="strength-bar">
                            ${[1, 2, 3, 4].map((i) => `<div class="strength-segment ${i <= strength ? 'filled' : ''} ${strength >= 3 ? 'high' : ''}"></div>`).join('')}
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        if (elements.socialWebGraph) {
            const nodes = topLinks.map((link, index) => {
                const angle = (index / topLinks.length) * Math.PI * 2;
                const radius = 34;
                const x = 50 + Math.cos(angle) * radius;
                const y = 50 + Math.sin(angle) * radius;
                const seenCount = Number(link.seenCount) || 0;
                const weight = Math.max(1, Math.round((seenCount / maxSeenCount) * 4));
                return { x, y, weight };
            });

            elements.socialWebGraph.innerHTML = `
                <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet" aria-label="Social graph">
                    ${nodes.map((node) => `<line x1="50" y1="50" x2="${node.x.toFixed(2)}" y2="${node.y.toFixed(2)}" stroke="rgba(128,147,255,0.5)" stroke-width="${node.weight * 0.5}" />`).join('')}
                    <circle cx="50" cy="50" r="8" class="social-node self"></circle>
                    ${nodes.map((node) => `<circle cx="${node.x.toFixed(2)}" cy="${node.y.toFixed(2)}" r="${2 + node.weight}" class="social-node"></circle>`).join('')}
                </svg>
            `;
        }
    }

    function renderReputation() {
        const container = elements.reputationList;
        
        if (!state.reputation || state.reputation.length === 0) {
            container.innerHTML = `
                <div class="empty-state" style="grid-column: span 2;">
                    <div class="empty-state-icon">${icons.star}</div>
                    <h3>No Reputation Yet</h3>
                    <p>Your reputation is unknown in the city. Build it through your actions — both good and bad will be remembered.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = state.reputation.map((rep, index) => {
            const label = getReputationLabel(rep.reputation_value);
            const percentage = Math.abs(rep.reputation_value);
            const valueClass = rep.reputation_value > 0 ? 'positive' : rep.reputation_value < 0 ? 'negative' : 'neutral';
            
            return `
                <div class="reputation-card" style="animation-delay: ${index * 0.05}s">
                    <div class="reputation-header">
                        <div class="reputation-icon ${rep.category}">
                            ${icons[rep.category] || icons.star}
                        </div>
                        <span class="reputation-category-name">${getCategoryLabel(rep.category)}</span>
                    </div>
                    <span class="reputation-value ${valueClass}">${rep.reputation_value > 0 ? '+' : ''}${rep.reputation_value}</span>
                    <div class="reputation-bar-bg">
                        <div class="reputation-bar-fill ${valueClass}" style="width: ${percentage}%;"></div>
                    </div>
                    <span class="reputation-label">${label}</span>
                </div>
            `;
        }).join('');

        // Render server-generated tags as premium chips
        renderReputationTags();
        
        // Update kills/deaths counters
        updateCombatStats();
        
        // Update character read with server-generated text
        updateCharacterRead();
    }

    function updateCombatStats() {
        const killsEl = document.getElementById('kills-count');
        const deathsEl = document.getElementById('deaths-count');
        const injuriesEl = document.getElementById('injuries-count');
        
        if (killsEl && state.counters) {
            killsEl.textContent = state.counters.kills || 0;
        }
        if (deathsEl && state.counters) {
            deathsEl.textContent = state.counters.deaths || 0;
        }
        if (injuriesEl && state.counters) {
            injuriesEl.textContent = state.counters.injuries || 0;
        }
    }

    function renderReputationTags() {
        const tagsContainer = elements.reputationTags;
        if (!tagsContainer) return;
        
        // Get tags from server data
        const tags = state.tags || [];
        
        if (tags.length === 0) {
            tagsContainer.innerHTML = '';
            return;
        }
        
        const tagStyles = state.config?.tagStyles || {
            success: { bg: 'rgba(52, 211, 153, 0.15)', color: '#34d399', border: 'rgba(52, 211, 153, 0.3)' },
            warning: { bg: 'rgba(251, 191, 36, 0.15)', color: '#fbbf24', border: 'rgba(251, 191, 36, 0.3)' },
            danger: { bg: 'rgba(248, 113, 113, 0.15)', color: '#f87171', border: 'rgba(248, 113, 113, 0.3)' },
            info: { bg: 'rgba(96, 165, 250, 0.15)', color: '#60a5fa', border: 'rgba(96, 165, 250, 0.3)' }
        };
        
        tagsContainer.innerHTML = tags.map(tag => {
            const style = tagStyles[tag.style] || tagStyles.info;
            return `
                <span class="reputation-tag-chip" style="background: ${style.bg}; color: ${style.color}; border: 1px solid ${style.border};">
                    ${tag.label}
                </span>
            `;
        }).join('');
    }

    function updateCharacterRead() {
        if (!elements.characterReadText) return;
        
        // Use server-generated characterRead if available
        if (state.characterRead) {
            elements.characterReadText.textContent = state.characterRead;
            return;
        }
        
        // Fallback client-side generation (for backwards compatibility)
        if (!state.reputation || state.reputation.length === 0) {
            elements.characterReadText.textContent = 'Your Lifeprint is still being written. The city doesn\'t know what to make of you yet.';
            return;
        }

        const general = state.reputation.find(r => r.category === 'general');
        const criminal = state.reputation.find(r => r.category === 'criminal');
        const business = state.reputation.find(r => r.category === 'business');

        const generalRep = general?.reputation_value || 0;
        const criminalRep = criminal?.reputation_value || 0;
        const businessRep = business?.reputation_value || 0;

        let text = '';

        // Overall standing
        if (generalRep >= 50) {
            text = `You are widely known and respected throughout Los Santos. Your name carries weight in conversations, and people tend to give you the benefit of the doubt. `;
        } else if (generalRep >= 25) {
            text = `You've built a solid reputation in the city. People know your name and generally view you in a positive light. `;
        } else if (generalRep >= 0) {
            text = `You're still finding your place in Los Santos. Some faces recognize you, but you haven't made a significant mark yet. `;
        } else if (generalRep >= -25) {
            text = `Whispers follow you in certain circles. Not everyone trusts you, and doors that should be open remain closed. `;
        } else {
            text = `Your reputation precedes you - and not in a good way. People cross the street to avoid you, and your name is spoken in hushed tones. `;
        }

        // Criminal standing
        if (criminalRep <= -50) {
            text += `On the streets, you're known as someone who operates outside the law. The underground respects you, but the law watches closely. `;
        } else if (criminalRep <= -25) {
            text += `There are rumors about your activities. Not quite notorious, but not clean either. `;
        } else if (criminalRep >= 25) {
            text += `You've built a legitimate life - at least on paper. The authorities have no reason to suspect you. `;
        }

        // Business
        if (businessRep >= 25) {
            text += `In the business world, you're seen as reliable and professional. Opportunities tend to find their way to you.`;
        } else if (businessRep <= -25) {
            text += `Business dealings with you require caution - at least that's what the smart money says.`;
        }

        elements.characterReadText.textContent = text;
    }

    function renderRumors() {
        const container = elements.rumorsList;
        
        if (!state.rumors || state.rumors.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">${icons.messageCircle}</div>
                    <h3>No Whispers Yet</h3>
                    <p>The city is quiet about you for now. Rumors and whispers will spread as you make a name for yourself.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = state.rumors.map((rumor, index) => `
            <div class="rumor-card" data-id="${rumor.id}" style="animation-delay: ${index * 0.05}s">
                <div class="rumor-header">
                    <span class="rumor-type-badge ${rumor.rumor_type}">
                        ${getRumorIcon(rumor.rumor_type)}
                        ${rumor.rumor_type.charAt(0).toUpperCase() + rumor.rumor_type.slice(1)}
                    </span>
                    <button class="memory-delete" data-id="${rumor.id}" title="Delete rumor">
                        ${icons.trash}
                    </button>
                </div>
                <p class="rumor-content">${rumor.content}</p>
                <div class="rumor-footer">
                    <span class="rumor-source">
                        ${icons.sparkles}
                        ${rumor.sourceName || 'Unknown'}
                    </span>
                    <span class="rumor-timestamp">
                        ${icons.clock}
                        ${formatDate(rumor.created_at)}
                    </span>
                </div>
            </div>
        `).join('');

        // Attach delete handlers
        container.querySelectorAll('.memory-delete').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                deleteRumor(parseInt(btn.dataset.id));
            });
        });
    }

    function render() {
        if (!elements) {
            console.error('[Lifeprint] Elements not initialized');
            return;
        }
        renderPlayer();
        renderMemories();
        renderRelationships();
        renderSocialLinks();
        renderReputation();
        renderRumors();
        renderBrain();
    }

    // =========================================================================
    // Memory Brain Visualization
    // =========================================================================

    // Brain state
    let brainData = {
        good: { count: 0, memories: [] },
        bad: { count: 0, memories: [] },
        rumors: { count: 0, memories: [] },
        other: { count: 0, memories: [] },
        total: 0,
        dominant: 'unknown',
        brainRead: ''
    };

    let activeBrainCategory = 'good';

    // Classify memory type into brain category
    function classifyMemoryType(memoryType) {
        const goodTypes = ['friendship', 'helpful', 'business_positive', 'trusted', 'ems_helped', 'positive', 'rescue'];
        const badTypes = ['death', 'kill', 'crime', 'arrest', 'npc_kill', 'npc_assault', 'vehicle_theft', 'hostile', 'negative', 'npc_vehicle_theft', 'gunshots'];
        const rumorTypes = ['rumor', 'city_whisper'];
        const otherTypes = ['social', 'encounter', 'vehicle', 'location', 'business', 'unknown', 'injury', 'vehicle_hit'];

        const type = (memoryType || '').toLowerCase();
        
        if (goodTypes.includes(type)) return 'good';
        if (badTypes.includes(type)) return 'bad';
        if (rumorTypes.includes(type)) return 'rumors';
        return 'other';
    }

    // Render the Memory Brain visualization
    function renderBrain() {
        console.log('[Lifeprint] Rendering brain visualization');
        
        // Calculate brain data from memories and rumors
        calculateBrainData();
        
        // Update counts
        const goodCount = document.getElementById('brain-good-count');
        const badCount = document.getElementById('brain-bad-count');
        const rumorsCount = document.getElementById('brain-rumors-count');
        const otherCount = document.getElementById('brain-other-count');
        const totalCount = document.getElementById('brain-total-count');
        
        if (goodCount) goodCount.textContent = brainData.good.count;
        if (badCount) badCount.textContent = brainData.bad.count;
        if (rumorsCount) rumorsCount.textContent = brainData.rumors.count;
        if (otherCount) otherCount.textContent = brainData.other.count;
        if (totalCount) totalCount.textContent = brainData.total;
        
        // Update progress bars
        const maxCount = Math.max(brainData.good.count, brainData.bad.count, brainData.rumors.count, brainData.other.count, 1);
        
        const goodBar = document.getElementById('brain-good-bar');
        const badBar = document.getElementById('brain-bad-bar');
        const rumorsBar = document.getElementById('brain-rumors-bar');
        const otherBar = document.getElementById('brain-other-bar');
        
        if (goodBar) goodBar.style.width = `${(brainData.good.count / maxCount) * 100}%`;
        if (badBar) badBar.style.width = `${(brainData.bad.count / maxCount) * 100}%`;
        if (rumorsBar) rumorsBar.style.width = `${(brainData.rumors.count / maxCount) * 100}%`;
        if (otherBar) otherBar.style.width = `${(brainData.other.count / maxCount) * 100}%`;
        
        // Update dominant category
        updateDominantCategory();
        
        // Update brain read text
        const brainReadText = document.getElementById('brain-read-text');
        if (brainReadText) {
            brainReadText.textContent = brainData.brainRead || generateBrainRead();
        }
        
        // Update brain zone visualization
        updateBrainZones();
        
        // Render recent memories for active category
        renderBrainRecentMemories();
    }

    // Calculate brain data from current state
    function calculateBrainData() {
        // Reset counts
        brainData = {
            good: { count: 0, memories: [] },
            bad: { count: 0, memories: [] },
            rumors: { count: 0, memories: [] },
            other: { count: 0, memories: [] },
            total: 0,
            dominant: 'unknown',
            brainRead: ''
        };
        
        // Process memories
        const memories = state.memories || [];
        memories.forEach(memory => {
            const category = classifyMemoryType(memory.memory_type);
            brainData[category].count++;
            brainData[category].memories.push(memory);
            brainData.total++;
        });
        
        // Process rumors
        const rumors = state.rumors || [];
        rumors.forEach(rumor => {
            brainData.rumors.count++;
            brainData.rumors.memories.push({
                id: rumor.id,
                memory_type: 'rumor',
                description: rumor.content,
                timestamp: rumor.created_at,
                title: rumor.rumor_type || 'Rumor'
            });
            brainData.total++;
        });
        
        // Sort memories by timestamp (newest first)
        Object.keys(brainData).forEach(key => {
            if (brainData[key].memories) {
                brainData[key].memories.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
            }
        });
    }

    // Update the dominant category display
    function updateDominantCategory() {
        const dominantValue = document.getElementById('brain-dominant-value');
        if (!dominantValue) return;
        
        // Find dominant category
        let maxCount = 0;
        let dominant = 'unknown';
        
        ['good', 'bad', 'rumors', 'other'].forEach(category => {
            if (brainData[category].count > maxCount) {
                maxCount = brainData[category].count;
                dominant = category;
            }
        });
        
        brainData.dominant = dominant;
        
        // Update display
        const labels = {
            good: 'Good Memories',
            bad: 'Dark Moments',
            rumors: 'City Whispers',
            other: 'Neutral Events',
            unknown: 'Unknown'
        };
        
        dominantValue.textContent = labels[dominant] || 'Unknown';
        dominantValue.className = `brain-dominant-value ${dominant}`;
    }

    // Update brain zone visualization with overlays and glows
    function updateBrainZones() {
        const zones = {
            good: document.getElementById('brain-zone-good'),
            bad: document.getElementById('brain-zone-bad'),
            rumors: document.getElementById('brain-zone-rumors'),
            other: document.getElementById('brain-zone-other')
        };
        
        const glows = {
            good: document.getElementById('glow-good'),
            bad: document.getElementById('glow-bad'),
            rumors: document.getElementById('glow-rumors'),
            other: document.getElementById('glow-other')
        };
        
        const visualization = document.getElementById('brain-visualization');
        
        // Remove pulse and active classes from all zones and glows
        Object.values(zones).forEach(zone => {
            if (zone) {
                zone.classList.remove('pulse-good', 'pulse-bad', 'pulse-rumors', 'pulse-other');
            }
        });
        
        Object.values(glows).forEach(glow => {
            if (glow) glow.classList.remove('active');
        });
        
        // Remove dominant classes from visualization
        if (visualization) {
            visualization.classList.remove('dominant-good', 'dominant-bad', 'dominant-rumors', 'dominant-other');
        }
        
        // Activate dominant zone and glow
        const dominant = brainData.dominant;
        if (zones[dominant]) {
            zones[dominant].classList.add('pulse-' + dominant);
        }
        
        if (glows[dominant]) {
            glows[dominant].classList.add('active');
        }
        
        // Add dominant class to visualization for image glow effect
        if (visualization && brainData.total > 0) {
            visualization.classList.add('dominant-' + dominant);
        }
    }

    // Generate brain read paragraph
    function generateBrainRead() {
        if (brainData.total === 0) {
            return 'Your Lifeprint is empty. The city doesn\'t know you yet. As you interact with Los Santos, your brain will fill with memories, relationships, and whispers from the streets.';
        }
        
        let text = '';
        
        // Overall composition
        const goodPercent = Math.round((brainData.good.count / brainData.total) * 100);
        const badPercent = Math.round((brainData.bad.count / brainData.total) * 100);
        const rumorPercent = Math.round((brainData.rumors.count / brainData.total) * 100);
        
        // Dominant theme
        if (brainData.dominant === 'good') {
            text = `Your Lifeprint radiates positivity. ${goodPercent}% of your memories are good — friendships formed, lives saved, and moments of genuine connection. `;
            if (badPercent > 20) {
                text += `Though you carry some dark moments (${badPercent}%), the light in your past shines brighter.`;
            } else {
                text += `The city sees you as someone who brings more light than shadow.`;
            }
        } else if (brainData.dominant === 'bad') {
            text = `Your Lifeprint carries the weight of darker days. ${badPercent}% of your memories are marked by conflict, loss, or regret. `;
            if (goodPercent > 20) {
                text += `Yet amidst the darkness, glimmers of hope persist — ${goodPercent}% of your story is written in light.`;
            } else {
                text += `The streets remember what you'd rather forget.`;
            }
        } else if (brainData.dominant === 'rumors') {
            text = `Your Lifeprint echoes with city whispers. The streets talk, and your name is on their lips. ${rumorPercent}% of what defines you in this city is hearsay and speculation. `;
            text += `Whether truth or fiction, these whispers shape how others see you.`;
        } else {
            text = `Your Lifeprint is a tapestry of ordinary moments — encounters, travels, and events that define your time in the city. `;
            text += `Neither saint nor sinner, you move through Los Santos leaving quiet ripples in your wake.`;
        }
        
        return text;
    }

    // Render recent memories for the selected category
    function renderBrainRecentMemories() {
        const container = document.getElementById('brain-recent-list');
        if (!container) return;
        
        const memories = brainData[activeBrainCategory]?.memories || [];
        
        if (memories.length === 0) {
            const emptyIcons = {
                good: icons.heart,
                bad: icons.skull,
                rumors: icons.messageCircle,
                other: icons.file
            };
            
            container.innerHTML = `
                <div class="brain-recent-empty">
                    ${emptyIcons[activeBrainCategory] || icons.file}
                    <p>No ${activeBrainCategory} memories yet</p>
                </div>
            `;
            return;
        }
        
        // Show up to 5 most recent
        const recentMemories = memories.slice(0, 5);
        
        const categoryIcons = {
            good: icons.heart,
            bad: icons.skull,
            rumors: icons.messageCircle,
            other: icons.file
        };
        
        container.innerHTML = recentMemories.map((memory, index) => {
            const title = memory.title || memory.description?.substring(0, 50) || 'Memory';
            const time = memory.timestamp ? formatDate(memory.timestamp) : 'Unknown';
            
            return `
                <div class="brain-recent-item ${activeBrainCategory}" style="animation-delay: ${index * 0.05}s">
                    <div class="brain-recent-item-icon">
                        ${categoryIcons[activeBrainCategory] || icons.file}
                    </div>
                    <div class="brain-recent-item-content">
                        <div class="brain-recent-item-title">${title}</div>
                        <div class="brain-recent-item-meta">${time}</div>
                    </div>
                </div>
            `;
        }).join('');
    }

    // Setup brain event listeners
    function setupBrainEventListeners() {
        // Category stat click handlers
        document.querySelectorAll('.brain-stat').forEach(stat => {
            stat.addEventListener('click', () => {
                const category = stat.dataset.category;
                if (category) {
                    activeBrainCategory = category;
                    
                    // Update active tab
                    document.querySelectorAll('.brain-recent-tab').forEach(tab => {
                        tab.classList.remove('active');
                        if (tab.dataset.recentCategory === category) {
                            tab.classList.add('active');
                        }
                    });
                    
                    renderBrainRecentMemories();
                }
            });
        });
        
        // Recent category tabs
        document.querySelectorAll('.brain-recent-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                const category = tab.dataset.recentCategory;
                if (category) {
                    activeBrainCategory = category;
                    
                    // Update active tab
                    document.querySelectorAll('.brain-recent-tab').forEach(t => t.classList.remove('active'));
                    tab.classList.add('active');
                    
                    renderBrainRecentMemories();
                }
            });
        });
        
        // Brain quadrant overlay click handlers
        document.querySelectorAll('.brain-quadrant-overlay').forEach(zone => {
            zone.addEventListener('click', () => {
                const category = zone.dataset.category || 'other';
                activeBrainCategory = category;
                
                // Update active tab
                document.querySelectorAll('.brain-recent-tab').forEach(tab => {
                    tab.classList.remove('active');
                    if (tab.dataset.recentCategory === category) {
                        tab.classList.add('active');
                    }
                });
                
                renderBrainRecentMemories();
            });
        });
    }

    // =========================================================================
    // Modal Functions
    // =========================================================================

    function openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.remove('hidden');
        }
    }

    function closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('hidden');
            // Reset form
            const inputs = modal.querySelectorAll('input, textarea, select');
            inputs.forEach(input => {
                if (input.tagName === 'SELECT') {
                    input.selectedIndex = 0;
                } else {
                    input.value = '';
                    input.style.borderColor = '';
                }
            });
            // Clear search results
            const searchResults = modal.querySelectorAll('.search-results');
            searchResults.forEach(el => el.classList.add('hidden'));
            // Reset selected target
            state.selectedTarget = null;
        }
    }

    function closeAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.add('hidden');
        });
    }

    // =========================================================================
    // Action Functions
    // =========================================================================

    function deleteMemory(memoryId) {
        nuiCallback('deleteMemory', { memoryId });
        state.memories = state.memories.filter(m => m.id !== memoryId);
        renderMemories();
        showToast('Memory forgotten', 'success');
    }

    function deleteRumor(rumorId) {
        nuiCallback('deleteRumor', { rumorId });
        state.rumors = state.rumors.filter(r => r.id !== rumorId);
        renderRumors();
        showToast('Rumor removed', 'success');
    }

    function saveMemory() {
        const type = document.getElementById('memory-type').value;
        const description = document.getElementById('memory-description').value.trim();
        const location = document.getElementById('memory-location').value.trim();
        const visibilitySelect = document.getElementById('memory-visibility');
        const visibility = visibilitySelect ? visibilitySelect.value : 'private';

        if (!description) {
            showToast('Please describe your memory', 'warning');
            return;
        }

        nuiCallback('addMemory', {
            targetIdentifier: state.selectedTarget?.identifier || null,
            memoryType: type,
            description: description,
            location: location,
            visibility: visibility,
            timestamp: Math.floor(Date.now() / 1000)
        });

        closeModal('memory-modal');
        showToast('Memory saved', 'success');

        setTimeout(() => nuiCallback('requestData'), 500);
    }

    function saveRumor() {
        const type = document.getElementById('rumor-type').value;
        const content = document.getElementById('rumor-content').value.trim();

        if (!content) {
            showToast('Please enter what you heard', 'warning');
            return;
        }

        nuiCallback('addRumor', {
            targetIdentifier: state.selectedTarget?.identifier || null,
            rumorType: type,
            content: content
        });

        closeModal('rumor-modal');
        showToast('Rumor recorded', 'success');

        setTimeout(() => nuiCallback('requestData'), 500);
    }

    async function searchPlayers(query, resultsId) {
        if (!query || query.length < 2) {
            document.getElementById(resultsId).classList.add('hidden');
            return;
        }

        if (isDebug) {
            const mockResults = [
                { identifier: 'MOCK001', name: 'John Smith' },
                { identifier: 'MOCK002', name: 'Jane Doe' },
                { identifier: 'MOCK003', name: 'Alex Johnson' }
            ].filter(p => p.name.toLowerCase().includes(query.toLowerCase()));

            displaySearchResults(mockResults, resultsId);
            return;
        }

        nuiCallback('searchPlayers', { query });
        state.currentSearchResultsId = resultsId;
    }

    function displaySearchResults(results, containerId) {
        const container = document.getElementById(containerId);
        if (!results || results.length === 0) {
            container.classList.add('hidden');
            return;
        }

        container.innerHTML = results.map(r => `
            <div class="search-result-item" data-identifier="${r.identifier}" data-name="${r.name}">
                <div class="name">${r.name}</div>
                <div class="identifier">${r.identifier}</div>
            </div>
        `).join('');

        container.classList.remove('hidden');

        container.querySelectorAll('.search-result-item').forEach(item => {
            item.addEventListener('click', () => {
                state.selectedTarget = {
                    identifier: item.dataset.identifier,
                    name: item.dataset.name
                };
                container.classList.add('hidden');
                
                const input = container.previousElementSibling;
                if (input) {
                    input.value = item.dataset.name;
                    input.style.borderColor = '#34d399';
                }
            });
        });
    }

    // =========================================================================
    // Toast Notifications
    // =========================================================================

    function showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        
        let icon = icons.info;
        if (type === 'success') icon = icons.check;
        if (type === 'error') icon = icons.x;
        if (type === 'warning') icon = icons.warning;

        toast.innerHTML = `${icon}<span class="toast-message">${message}</span>`;
        elements.toastContainer.appendChild(toast);

        // Auto-dismiss after 3 seconds
        setTimeout(() => {
            toast.classList.add('removing');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // =========================================================================
    // Event Handlers
    // =========================================================================

    function setupEventListeners() {
        // Close button
        elements.closeBtn.addEventListener('click', () => {
            nuiCallback('close');
        });

        // Tab navigation with smooth transition
        document.querySelectorAll('.nav-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
                tab.classList.add('active');

                const tabId = tab.dataset.tab;
                document.querySelectorAll('.tab-content').forEach(content => {
                    content.classList.remove('active');
                });
                
                setTimeout(() => {
                    document.getElementById(`tab-${tabId}`).classList.add('active');
                }, 50);
            });
        });

        // Timeline filters
        elements.timelineFilters.addEventListener('click', (e) => {
            if (e.target.classList.contains('filter-pill')) {
                document.querySelectorAll('.filter-pill').forEach(f => f.classList.remove('active'));
                e.target.classList.add('active');
                state.activeFilter = e.target.dataset.filter;
                renderMemories();
            }
        });

        // People search
        let peopleSearchTimeout;
        elements.peopleSearch.addEventListener('input', (e) => {
            clearTimeout(peopleSearchTimeout);
            peopleSearchTimeout = setTimeout(() => {
                state.peopleSearchQuery = e.target.value.trim();
                renderRelationships();
            }, 200);
        });

        // Add memory button
        document.getElementById('add-memory-btn').addEventListener('click', () => {
            openModal('memory-modal');
        });

        // Add rumor button
        document.getElementById('add-rumor-btn').addEventListener('click', () => {
            openModal('rumor-modal');
        });

        // Modal close buttons
        document.querySelectorAll('.modal-close, .btn-secondary[data-modal]').forEach(btn => {
            btn.addEventListener('click', () => {
                const modalId = btn.dataset.modal;
                if (modalId) {
                    closeModal(modalId);
                }
            });
        });

        // Save buttons
        document.getElementById('save-memory-btn').addEventListener('click', saveMemory);
        document.getElementById('save-rumor-btn').addEventListener('click', saveRumor);

        // Memory person search
        let memorySearchTimeout;
        document.getElementById('memory-person-search').addEventListener('input', (e) => {
            clearTimeout(memorySearchTimeout);
            memorySearchTimeout = setTimeout(() => {
                searchPlayers(e.target.value, 'memory-search-results');
            }, 300);
        });

        // Rumor person search
        let rumorSearchTimeout;
        document.getElementById('rumor-person-search').addEventListener('input', (e) => {
            clearTimeout(rumorSearchTimeout);
            rumorSearchTimeout = setTimeout(() => {
                searchPlayers(e.target.value, 'rumor-search-results');
            }, 300);
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (document.querySelector('.modal:not(.hidden)')) {
                    closeAllModals();
                } else if (recentFacesVisible) {
                    // Close recent faces panel
                    handleCloseRecentFaces();
                    nuiCallback('closeRecentFaces');
                } else if (state.adminVisible) {
                    // Close admin panel
                    handleAdminClose();
                    nuiCallback('close');
                } else if (state.visible) {
                    nuiCallback('close');
                }
            }
        });

        // Click outside modal to close
        document.querySelectorAll('.modal').forEach(modal => {
            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    modal.classList.add('hidden');
                }
            });
        });

        if (elements.debugCloseBtn) {
            elements.debugCloseBtn.addEventListener('click', () => {
                if (elements.debugPanel) {
                    elements.debugPanel.classList.add('nui-hidden');
                }
            });
        }
    }

    // =========================================================================
    // NUI Message Handlers
    // =========================================================================

    function setupNUIHandlers() {
        console.log('[Lifeprint] Setting up NUI message handlers');
        
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            // Always log incoming messages for debugging
            console.log('[Lifeprint] Received raw message:', data);
            
            let payload = data;
            if (typeof data === 'string') {
                try {
                    payload = JSON.parse(data);
                    console.log('[Lifeprint] Parsed JSON payload:', payload);
                } catch (e) {
                    console.error('[Lifeprint] Failed to parse message:', e);
                    return;
                }
            }

            if (!payload) {
                console.error('[Lifeprint] No payload in message');
                return;
            }

            const action = payload.action;
            const payloadData = payload.data;
            
            console.log('[Lifeprint] Processing action:', action, 'with data:', payloadData);

            if (!action) {
                console.error('[Lifeprint] No action in payload');
                return;
            }

            try {
                switch (action) {
                    case 'showLoading':
                        handleShowLoading();
                        break;
                    case 'open':
                        handleOpen(payloadData || {});
                        break;
                    case 'close':
                        handleClose();
                        break;
                    case 'updateData':
                        handleUpdate(payloadData || {});
                        break;
                    case 'searchResults':
                        handleSearchResults(payloadData);
                        break;
                    case 'setVisible':
                        handleSetVisible(payloadData);
                        break;
                    case 'openAdminPanel':
                        handleAdminOpen(payloadData || {});
                        break;
                    case 'closeAdminPanel':
                        handleAdminClose();
                        break;
                    case 'adminPlayerData':
                        handleAdminPlayerData(payloadData || {});
                        break;
                    case 'adminWipeComplete':
                        handleAdminWipeComplete(payloadData || {});
                        break;
                    case 'showMemoryPopup':
                        handleShowMemoryPopup(payloadData || {});
                        break;
                    case 'openRecentFaces':
                        handleOpenRecentFaces(payloadData || {});
                        break;
                    case 'rememberFaceResult':
                        handleRememberFaceResult(payloadData || {});
                        break;
                    case 'openSettings':
                        handleOpenSettings(payloadData || {});
                        break;
                    case 'updateAvatar':
                        handleUpdateAvatar(payloadData || {});
                        break;
                    case 'notify':
                        handleNotify(payloadData || {});
                        break;
                    case 'showMemoryNotification':
                        handleShowMemoryNotification(payloadData || {});
                        break;
                    case 'reputationNotification':
                        handleReputationNotification(payloadData || {});
                        break;
                    case 'updateReputationLive':
                        handleUpdateReputationLive(payloadData || {});
                        break;
                    case 'journalNotification':
                        handleJournalNotification(payloadData || {});
                        break;
                    case 'refreshTab':
                        handleRefreshTab(payloadData || {});
                        break;
                    case 'showDebugPanel':
                        handleShowDebugPanel(payloadData || {});
                        break;
                    case 'updateBrain':
                        handleUpdateBrain(payloadData || {});
                        break;
                    default:
                        console.log('[Lifeprint] Unknown action:', action);
                }
            } catch (err) {
                console.error('[Lifeprint] Error handling action', action, ':', err);
            }
        });
        
        console.log('[Lifeprint] NUI handlers registered');
    }

    function handleShowLoading() {
        console.log('[Lifeprint] handleShowLoading called - showing loading screen');
        state.visible = true;
        state.loading = true;
        
        // Show the app container with loading screen visible
        if (elements.app) {
            elements.app.classList.remove('nui-hidden');
        }
        
        // Ensure loading screen is visible
        if (elements.loadingScreen) {
            elements.loadingScreen.classList.remove('hidden');
        }
        
        // Hide main container while loading
        if (elements.mainContainer) {
            elements.mainContainer.classList.add('hidden');
        }
    }

    function handleOpen(data) {
        try {
            console.log('[Lifeprint] handleOpen called with data:', data);
            state.visible = true;
            state.loading = false;

            if (data) {
                if (data.player) state.player = data.player;
                if (data.memories) state.memories = data.memories;
                if (data.relationships) state.relationships = data.relationships;
                if (data.socialLinks) state.socialLinks = data.socialLinks;
                if (data.reputation) state.reputation = data.reputation;
                if (data.rumors) state.rumors = data.rumors;
                if (data.counters) state.counters = data.counters;
                if (data.tags) state.tags = data.tags;
                if (data.characterRead) state.characterRead = data.characterRead;
                if (data.config) state.config = data.config;
            }

            console.log('[Lifeprint] Hiding loading screen, showing main container');
            
            // Remove nui-hidden from app container (show entire UI)
            if (elements.app) {
                elements.app.classList.remove('nui-hidden');
            }
            
            if (elements.loadingScreen) {
                elements.loadingScreen.classList.add('hidden');
            } else {
                console.error('[Lifeprint] loadingScreen element is null!');
            }
            
            if (elements.mainContainer) {
                elements.mainContainer.classList.remove('hidden');
            } else {
                console.error('[Lifeprint] mainContainer element is null!');
            }

            render();
        } catch (err) {
            console.error('[Lifeprint] Error in handleOpen:', err);
        }
    }

    function handleClose() {
        console.log('[Lifeprint] handleClose called');
        state.visible = false;
        
        // Hide main container
        if (elements.mainContainer) {
            elements.mainContainer.classList.add('hidden');
        }
        
        // Reset loading screen for next open
        if (elements.loadingScreen) {
            elements.loadingScreen.classList.remove('hidden');
        }
        
        // Hide entire app (add nui-hidden back)
        if (elements.app) {
            elements.app.classList.add('nui-hidden');
        }

        if (elements.debugPanel) {
            elements.debugPanel.classList.add('nui-hidden');
        }
        
        closeAllModals();
    }

    function handleUpdate(data) {
        if (data.player) state.player = data.player;
        if (data.memories) state.memories = data.memories;
        if (data.relationships) state.relationships = data.relationships;
        if (data.socialLinks) state.socialLinks = data.socialLinks;
        if (data.reputation) state.reputation = data.reputation;
        if (data.rumors) state.rumors = data.rumors;
        if (data.counters) state.counters = data.counters;
        if (data.tags) state.tags = data.tags;
        if (data.characterRead) state.characterRead = data.characterRead;

        render();
    }

    function handleSearchResults(data) {
        displaySearchResults(data, state.currentSearchResultsId);
    }

    function handleSetVisible(data) {
        if (data.visible) {
            elements.mainContainer.classList.remove('hidden');
        } else {
            elements.mainContainer.classList.add('hidden');
        }
    }

    // =========================================================================
    // Memory Popup Functions
    // =========================================================================

    let memoryPopupTimeout = null;

    function handleShowMemoryPopup(data) {
        console.log('[Lifeprint] Memory popup triggered:', data);
        
        if (!elements.memoryPopup) return;
        
        // Clear any existing timeout
        if (memoryPopupTimeout) {
            clearTimeout(memoryPopupTimeout);
        }
        
        // Update popup content
        if (elements.memoryPopupName) {
            elements.memoryPopupName.textContent = `You recognize ${data.targetName || 'someone'}`;
        }
        
        if (elements.memoryPopupMemory) {
            if (data.memoryTitle) {
                // Truncate if too long
                const truncatedMemory = data.memoryTitle.length > 80 
                    ? data.memoryTitle.substring(0, 77) + '...' 
                    : data.memoryTitle;
                elements.memoryPopupMemory.textContent = `Last memory: ${truncatedMemory}`;
            } else {
                elements.memoryPopupMemory.textContent = '';
            }
        }
        
        if (elements.memoryPopupNote) {
            if (data.note) {
                // Truncate if too long
                const truncatedNote = data.note.length > 100 
                    ? data.note.substring(0, 97) + '...' 
                    : data.note;
                elements.memoryPopupNote.textContent = `Note: "${truncatedNote}"`;
            } else {
                elements.memoryPopupNote.textContent = '';
            }
        }
        
        // Show popup
        elements.memoryPopup.classList.remove('hidden', 'removing');
        
        // Auto-dismiss after 5 seconds
        memoryPopupTimeout = setTimeout(() => {
            if (elements.memoryPopup) {
                elements.memoryPopup.classList.add('removing');
                setTimeout(() => {
                    if (elements.memoryPopup) {
                        elements.memoryPopup.classList.add('hidden');
                        elements.memoryPopup.classList.remove('removing');
                    }
                }, 400);
            }
        }, 5000);
    }

    // =========================================================================
    // Memory Pulse Notification System
    // Immersive notification feedback with screen-edge pulse effects
    // =========================================================================

    const notificationQueue = [];
    let isShowingNotification = false;
    const MAX_VISIBLE_NOTIFICATIONS = 3;
    const NOTIFICATION_QUEUE_DELAY = 300;

    // Notification icons (inline SVG)
    const notificationIcons = {
        memory: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2z"/><path d="M12 6v6l4 2"/></svg>',
        face: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="8" r="4"/><path d="M20 21a8 8 0 0 0-16 0"/></svg>',
        relationship: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
        location: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
        rumor: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
        reputation: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
        info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>',
        success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
        warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>'
    };

    // Show screen-edge pulse overlay
    function showMemoryPulseOverlay(importance) {
        const overlay = document.getElementById('memory-pulse-overlay');
        if (!overlay) return;

        // Remove any existing animation classes
        overlay.classList.remove('hidden', 'active', 'lifechanging');

        // Add appropriate animation class
        if (importance === 'lifechanging') {
            overlay.classList.add('lifechanging');
        } else {
            overlay.classList.add('active');
        }

        // Hide after animation completes
        setTimeout(() => {
            overlay.classList.add('hidden');
            overlay.classList.remove('active', 'lifechanging');
        }, 2500);
    }

    // Create notification element
    function createNotificationElement(data) {
        const notif = document.createElement('div');
        notif.className = `notification type-${data.type || 'info'}`;
        
        // Add importance class for styling
        if (data.importance) {
            notif.classList.add(`importance-${data.importance}`);
        }

        const iconSvg = notificationIcons[data.type] || notificationIcons.info;

        notif.innerHTML = `
            <div class="notification-icon">${iconSvg}</div>
            <div class="notification-content">
                <div class="notification-title">${data.title || 'Lifeprint'}</div>
                <div class="notification-message">${data.message || ''}</div>
            </div>
        `;

        return notif;
    }

    // Show notification with queue support
    function showNotification(data) {
        const container = document.getElementById('notification-container');
        if (!container) {
            console.error('[Lifeprint] Notification container not found');
            return;
        }

        // Add to queue
        notificationQueue.push(data);

        // Process queue if not already processing
        if (!isShowingNotification) {
            processNotificationQueue();
        }
    }

    // Process notification queue
    function processNotificationQueue() {
        const container = document.getElementById('notification-container');
        if (!container) return;

        // Check if we can show more notifications
        const currentNotifications = container.querySelectorAll('.notification:not(.hiding)').length;
        
        if (currentNotifications >= MAX_VISIBLE_NOTIFICATIONS) {
            setTimeout(processNotificationQueue, NOTIFICATION_QUEUE_DELAY);
            return;
        }

        if (notificationQueue.length === 0) {
            isShowingNotification = false;
            return;
        }

        isShowingNotification = true;
        const data = notificationQueue.shift();

        // Create and show notification
        const notif = createNotificationElement(data);
        container.appendChild(notif);

        // Show pulse overlay for major/lifechanging
        if (data.showPulse) {
            showMemoryPulseOverlay(data.importance);
        }

        // Auto-hide notification
        const duration = data.duration || 5000;
        setTimeout(() => {
            notif.classList.add('hiding');
            setTimeout(() => {
                if (notif.parentNode) {
                    notif.parentNode.removeChild(notif);
                }
                // Process next in queue
                processNotificationQueue();
            }, 200);
        }, duration);

        // Process next with delay
        setTimeout(processNotificationQueue, NOTIFICATION_QUEUE_DELAY);
    }

    // Handle memory notification (with pulse effects)
    function handleShowMemoryNotification(data) {
        console.log('[Lifeprint] Memory notification received:', data);
        
        // Show notification with pulse effects
        showNotification({
            type: data.type || 'memory',
            title: data.title || 'Memory Surfaced',
            message: data.message || '',
            duration: data.duration || 5000,
            importance: data.importance || 'minor',
            showPulse: data.showPulse || false,
            showGlow: data.showGlow || false
        });
    }

    // Handle standard notification (backward compatible)
    function handleNotify(data) {
        console.log('[Lifeprint] Standard notification received:', data);
        
        if (typeof data === 'string') {
            data = { message: data, type: 'info' };
        }

        showNotification({
            type: data.type || 'info',
            title: data.title || 'Lifeprint',
            message: data.message || '',
            duration: data.duration || 4000,
            importance: 'minor'
        });
    }

    function handleShowDebugPanel(data) {
        if (!elements.debugPanel || !elements.debugPanelContent) return;

        elements.debugPanelContent.textContent = JSON.stringify(data || {}, null, 2);
        elements.debugPanel.classList.remove('nui-hidden');
    }

    // =========================================================================
    // Reputation Change Notifications
    // =========================================================================

    function handleReputationNotification(data) {
        console.log('[Lifeprint] Reputation notification received:', data);
        
        if (!data || !data.tag) return;
        
        // Determine importance based on priority
        let importance = 'notable';
        if (data.priority >= 5) {
            importance = 'major';
        } else if (data.priority >= 6) {
            importance = 'lifechanging';
        }
        
        // Map style to notification type for toast colors
        let notifyType = 'info';
        if (data.style === 'danger') {
            notifyType = 'error';
        } else if (data.style === 'warning') {
            notifyType = 'warning';
        } else if (data.style === 'success') {
            notifyType = 'success';
        }
        
        // Show the notification with appropriate styling
        showNotification({
            type: notifyType,
            title: 'Lifeprint Reputation',
            message: data.message || ('New trait unlocked: ' + data.tag),
            duration: data.duration || 5000,
            importance: importance,
            tag: data.tag,
            style: data.style
        });
        
        // Show memory pulse overlay for major/lifechanging
        if (importance === 'major' || importance === 'lifechanging') {
            showMemoryPulseOverlay(importance, 'reputation');
        }
    }

    function handleUpdateReputationLive(data) {
        console.log('[Lifeprint] Live reputation update received:', data);
        
        // Only update if UI is currently visible and on reputation tab
        if (!state.visible) return;
        
        // Update state with new reputation data
        if (data.tags) {
            state.reputationTags = data.tags;
        }
        if (data.counters) {
            state.reputationCounters = data.counters;
        }
        if (data.characterRead) {
            state.characterRead = data.characterRead;
        }
        
        // Re-render reputation section if on that tab
        if (state.activeTab === 'reputation') {
            updateReputationSection();
        }
    }

    function handleJournalNotification(data) {
        console.log('[Lifeprint] Journal notification received:', data);
        
        if (!data) return;
        
        // Determine notification type
        let notifyType = 'info';
        if (data.type === 'memory') {
            notifyType = 'success';
        } else if (data.type === 'relationship') {
            notifyType = 'info';
        } else if (data.type === 'rumor') {
            notifyType = 'warning';
        } else if (data.type === 'reputation') {
            notifyType = 'success';
        }
        
        // Show the notification
        showNotification({
            type: notifyType,
            title: data.title || 'Lifeprint Updated',
            message: data.message || 'Your Lifeprint has been updated.',
            duration: data.duration || 4000,
            importance: data.importance || 'minor'
        });
        
        // Show pulse for notable+ updates
        if (data.importance === 'notable' || data.importance === 'major' || data.importance === 'lifechanging') {
            showMemoryPulseOverlay(data.importance, data.type || 'journal');
        }
    }

    function handleRefreshTab(data) {
        console.log('[Lifeprint] Tab refresh requested:', data);
        
        // Only refresh if UI is visible
        if (!state.visible) return;
        
        // Refresh specific tab or all data
        if (data && data.tab) {
            // Request fresh data from server for specific tab
            if (data.tab === 'timeline') {
                // Re-render memories from current state
                if (state.memories && elements.timeline) {
                    renderMemories(state.memories);
                }
            } else if (data.tab === 'people') {
                // Re-render relationships
                if (state.relationships && elements.relationshipsList) {
                    renderRelationships(state.relationships);
                }
            } else if (data.tab === 'reputation') {
                // Re-render reputation
                updateReputationSection();
            } else if (data.tab === 'rumors') {
                // Re-render rumors
                if (state.rumors && elements.rumorsList) {
                    renderRumors(state.rumors);
                }
            }
        } else if (data && data.all) {
            // Full refresh - request all data from server
            NUI.request('requestData', {});
        }
    }

    function updateReputationSection() {
        // Update reputation tags display
        const tagsContainer = document.getElementById('reputation-tags');
        if (tagsContainer && state.reputationTags) {
            tagsContainer.innerHTML = state.reputationTags.map(function(tag) {
                const style = getTagStyle(tag.style);
                return '<div class="reputation-chip" style="' + style + '">' + 
                    '<span class="chip-label">' + escapeHtml(tag.label) + '</span>' +
                    '</div>';
            }).join('');
        }
        
        // Update character read
        const characterReadEl = document.getElementById('character-read');
        if (characterReadEl && state.characterRead) {
            characterReadEl.textContent = state.characterRead;
        }
        
        // Update counters display
        updateCountersDisplay();
    }

    function updateCountersDisplay() {
        const counters = state.reputationCounters || {};
        const counterElements = {
            'arrests': document.getElementById('counter-arrests'),
            'ems_visits': document.getElementById('counter-ems'),
            'crashes': document.getElementById('counter-crashes'),
            'meetings': document.getElementById('counter-meetings'),
            'helpful_actions': document.getElementById('counter-helpful'),
            'suspicious_actions': document.getElementById('counter-suspicious'),
            'kills': document.getElementById('counter-kills'),
            'deaths': document.getElementById('counter-deaths')
        };
        
        for (const [key, el] of Object.entries(counterElements)) {
            if (el && counters[key] !== undefined) {
                el.textContent = counters[key];
            }
        }
    }

    function getTagStyle(styleName) {
        const styles = {
            success: 'background: rgba(52, 211, 153, 0.15); color: #34d399; border: 1px solid rgba(52, 211, 153, 0.3);',
            danger: 'background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3);',
            warning: 'background: rgba(251, 191, 36, 0.15); color: #fbbf24; border: 1px solid rgba(251, 191, 36, 0.3);',
            info: 'background: rgba(96, 165, 250, 0.15); color: #60a5fa; border: 1px solid rgba(96, 165, 250, 0.3);'
        };
        return styles[styleName] || styles.info;
    }

    // Handle brain update from server
    function handleUpdateBrain(data) {
        console.log('[Lifeprint] Brain update received:', data);
        
        if (data.brainRead) {
            brainData.brainRead = data.brainRead;
        }
        
        if (data.dominant) {
            brainData.dominant = data.dominant;
        }
        
        // Re-render if on brain tab
        const brainTab = document.getElementById('tab-brain');
        if (brainTab && brainTab.classList.contains('active')) {
            renderBrain();
        }
    }

    // =========================================================================
    // Recent Faces Functions
    // =========================================================================

    let recentFacesVisible = false;
    let recentFacesList = [];

    function formatTimeAgo(seconds) {
        if (seconds < 60) return 'Just now';
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
        return `${Math.floor(seconds / 3600)}h ago`;
    }

    function handleOpenRecentFaces(data) {
        console.log('[Lifeprint] Recent faces panel opening', data);
        
        recentFacesVisible = true;
        recentFacesList = data.faces || [];
        
        // Hide other panels
        if (elements.mainContainer) {
            elements.mainContainer.classList.add('hidden');
        }
        if (elements.loadingScreen) {
            elements.loadingScreen.classList.add('hidden');
        }
        if (elements.adminContainer) {
            elements.adminContainer.classList.add('nui-hidden');
        }
        if (elements.memoryPopup) {
            elements.memoryPopup.classList.add('hidden');
        }
        
        // Show recent faces panel
        if (elements.recentFacesPanel) {
            elements.recentFacesPanel.classList.remove('nui-hidden');
        }
        
        // Render the list
        renderRecentFacesList();
    }

    function handleCloseRecentFaces() {
        console.log('[Lifeprint] Recent faces panel closing');
        
        recentFacesVisible = false;
        
        if (elements.recentFacesPanel) {
            elements.recentFacesPanel.classList.add('nui-hidden');
        }
    }

    function renderRecentFacesList() {
        const container = elements.recentFacesList;
        if (!container) return;
        
        if (recentFacesList.length === 0) {
            container.innerHTML = `
                <div class="recent-faces-empty">
                    <div class="recent-faces-empty-icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                            <circle cx="9" cy="7" r="4"/>
                            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                        </svg>
                    </div>
                    <h3>No Recent Faces</h3>
                    <p>Walk near other players in the city and they'll appear here for you to remember later.</p>
                </div>
            `;
            return;
        }
        
        container.innerHTML = recentFacesList.map((face, index) => `
            <div class="recent-face-entry" data-server-id="${face.serverId}" style="animation-delay: ${index * 0.05}s">
                <div class="recent-face-avatar">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                        <circle cx="12" cy="7" r="4"/>
                    </svg>
                </div>
                <div class="recent-face-info">
                    <div class="recent-face-name">${face.name}</div>
                    <div class="recent-face-meta">
                        <span class="recent-face-server-id">ID: ${face.serverId}</span>
                        <span class="recent-face-location">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                                <circle cx="12" cy="10" r="3"/>
                            </svg>
                            ${face.location}
                        </span>
                        <span>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                <circle cx="12" cy="12" r="10"/>
                                <polyline points="12 6 12 12 16 14"/>
                            </svg>
                            ${formatTimeAgo(face.timeAgo)}
                        </span>
                    </div>
                </div>
                <div class="recent-face-actions">
                    <button class="recent-face-remember-btn" data-server-id="${face.serverId}">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="12" cy="12" r="3"/>
                            <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
                        </svg>
                        Remember
                    </button>
                </div>
            </div>
        `).join('');
        
        // Attach remember button handlers
        container.querySelectorAll('.recent-face-remember-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const serverId = parseInt(btn.dataset.serverId);
                if (serverId) {
                    rememberRecentFace(serverId);
                }
            });
        });
    }

    function rememberRecentFace(serverId) {
        console.log('[Lifeprint] Remembering face:', serverId);
        
        nuiCallback('rememberRecentFace', { serverId });
        
        // Show loading state on button
        const btn = document.querySelector(`.recent-face-remember-btn[data-server-id="${serverId}"]`);
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = `
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="spin">
                    <circle cx="12" cy="12" r="10"/>
                    <polyline points="12 6 12 12 16 14"/>
                </svg>
                Saving...
            `;
        }
    }

    function handleRememberFaceResult(data) {
        console.log('[Lifeprint] Remember face result:', data);
        
        if (data.success) {
            showToast('Face remembered successfully', 'success');
            
            // Remove from list
            recentFacesList = recentFacesList.filter(f => f.serverId !== data.serverId);
            renderRecentFacesList();
            
            // Close panel if empty
            if (recentFacesList.length === 0) {
                handleCloseRecentFaces();
                nuiCallback('closeRecentFaces');
            }
        } else {
            showToast(data.message || 'Failed to remember face', 'error');
            
            // Re-enable button
            const btn = document.querySelector(`.recent-face-remember-btn[data-server-id="${data.serverId}"]`);
            if (btn) {
                btn.disabled = false;
                btn.innerHTML = `
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <circle cx="12" cy="12" r="3"/>
                        <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
                    </svg>
                    Remember
                `;
            }
        }
    }

    // =========================================================================
    // Admin Panel Functions
    // =========================================================================

    function handleAdminOpen(data) {
        console.log('[Lifeprint] Admin panel opening');
        state.adminVisible = true;
        state.isAdmin = true;
        state.visible = false;
        
        // Hide main container, show admin container
        if (elements.mainContainer) {
            elements.mainContainer.classList.add('hidden');
        }
        if (elements.loadingScreen) {
            elements.loadingScreen.classList.add('hidden');
        }
        if (elements.adminContainer) {
            elements.adminContainer.classList.remove('nui-hidden');
        }
        
        // Store config if provided
        if (data.config) {
            state.config = data.config;
        }
    }

    function handleAdminClose() {
        console.log('[Lifeprint] Admin panel closing');
        state.adminVisible = false;
        state.isAdmin = false;
        state.adminPlayer = null;
        state.adminPlayerData = null;
        
        if (elements.adminContainer) {
            elements.adminContainer.classList.add('nui-hidden');
        }
        
        // Reset admin UI
        resetAdminUI();
    }

    function handleAdminPlayerData(data) {
        console.log('[Lifeprint] Admin player data received:', data);
        state.adminPlayerData = data;
        state.adminPlayer = data.player;
        
        renderAdminPlayerData();
    }

    function handleAdminWipeComplete(data) {
        console.log('[Lifeprint] Admin wipe complete:', data);
        showToast('Player data wiped successfully', 'success');
        
        // Clear the admin player data and reset the UI
        state.adminPlayerData = {
            memories: [],
            relationships: [],
            reputation: [],
            rumors: [],
            counters: {},
            tags: [],
            characterRead: ''
        };
        
        // Re-render with empty data
        renderAdminPlayerData();
    }

    function resetAdminUI() {
        const playerIdInput = document.getElementById('admin-player-id');
        if (playerIdInput) playerIdInput.value = '';
        
        const playerInfo = document.getElementById('admin-player-info');
        if (playerInfo) playerInfo.classList.add('hidden');
        
        const adminTabs = document.getElementById('admin-tabs');
        if (adminTabs) adminTabs.classList.add('hidden');
        
        const tabContent = document.getElementById('admin-tab-content');
        if (tabContent) tabContent.classList.add('hidden');
    }

    function renderAdminPlayerData() {
        if (!state.adminPlayer) return;
        
        // Show player info
        const playerInfo = document.getElementById('admin-player-info');
        if (playerInfo) playerInfo.classList.remove('hidden');
        
        // Update player details
        const nameEl = document.getElementById('admin-player-name');
        const idEl = document.getElementById('admin-player-identifier');
        if (nameEl) nameEl.textContent = state.adminPlayer.name || 'Unknown';
        if (idEl) idEl.textContent = state.adminPlayer.identifier || '--';
        
        // Show tabs and content
        const adminTabs = document.getElementById('admin-tabs');
        const tabContent = document.getElementById('admin-tab-content');
        if (adminTabs) adminTabs.classList.remove('hidden');
        if (tabContent) tabContent.classList.remove('hidden');
        
        // Update data summary
        const memoriesCount = document.getElementById('admin-memories-count');
        const relationshipsCount = document.getElementById('admin-relationships-count');
        const rumorsCount = document.getElementById('admin-rumors-count');
        
        if (memoriesCount) memoriesCount.textContent = (state.adminPlayerData.memories || []).length;
        if (relationshipsCount) relationshipsCount.textContent = (state.adminPlayerData.relationships || []).length;
        if (rumorsCount) rumorsCount.textContent = (state.adminPlayerData.rumors || []).length;
        
        // Update character read
        const characterReadText = document.getElementById('admin-character-read-text');
        if (characterReadText) {
            characterReadText.textContent = state.adminPlayerData.characterRead || 'No reputation data available.';
        }
        
        // Render tags
        renderAdminTags();
        
        // Render counters
        renderAdminCounters();
    }

    function renderAdminTags() {
        const container = document.getElementById('admin-tags-container');
        if (!container) return;
        
        const tags = state.adminPlayerData?.tags || [];
        
        if (tags.length === 0) {
            container.innerHTML = '<span class="admin-tag-chip" style="background: var(--bg-tertiary); color: var(--text-muted);">No reputation tags</span>';
            return;
        }
        
        const tagStyles = {
            success: { bg: 'rgba(52, 211, 153, 0.15)', color: '#34d399' },
            warning: { bg: 'rgba(251, 191, 36, 0.15)', color: '#fbbf24' },
            danger: { bg: 'rgba(248, 113, 113, 0.15)', color: '#f87171' },
            info: { bg: 'rgba(96, 165, 250, 0.15)', color: '#60a5fa' }
        };
        
        container.innerHTML = tags.map(tag => {
            const style = tagStyles[tag.style] || tagStyles.info;
            return `<span class="admin-tag-chip" style="background: ${style.bg}; color: ${style.color};">${tag.label}</span>`;
        }).join('');
    }

    function renderAdminCounters() {
        const container = document.getElementById('admin-counters-list');
        if (!container) return;
        
        const counters = state.adminPlayerData?.counters || {};
        const counterTypes = state.config?.counterTypes || ['arrests', 'ems_visits', 'crashes', 'meetings', 'helpful_actions', 'suspicious_actions'];
        
        container.innerHTML = counterTypes.map(type => {
            const value = counters[type] || 0;
            return `
                <div class="admin-counter-row">
                    <span class="admin-counter-label">${type.replace(/_/g, ' ')}</span>
                    <input type="number" class="admin-counter-input" data-counter="${type}" value="${value}" min="0">
                    <button class="admin-counter-btn" data-counter="${type}">Set</button>
                </div>
            `;
        }).join('');
        
        // Attach counter button handlers
        container.querySelectorAll('.admin-counter-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const counterType = btn.dataset.counter;
                const input = container.querySelector(`input[data-counter="${counterType}"]`);
                if (input && state.adminPlayer) {
                    nuiCallback('adminSetCounter', {
                        targetIdentifier: state.adminPlayer.identifier,
                        counterType: counterType,
                        value: parseInt(input.value) || 0
                    });
                    showToast(`Counter ${counterType} updated`, 'success');
                }
            });
        });
    }

    function switchAdminTab(tabId) {
        state.adminActiveTab = tabId;
        
        // Update tab buttons
        document.querySelectorAll('.admin-tab').forEach(tab => {
            tab.classList.remove('active');
            if (tab.dataset.adminTab === tabId) {
                tab.classList.add('active');
            }
        });
        
        // Update tab panels
        document.querySelectorAll('.admin-tab-panel').forEach(panel => {
            panel.classList.remove('active');
        });
        
        const activePanel = document.getElementById(`admin-tab-${tabId}`);
        if (activePanel) activePanel.classList.add('active');
    }

    function setupAdminEventListeners() {
        // Close button
        const closeBtn = document.getElementById('admin-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                nuiCallback('close');
                handleAdminClose();
            });
        }
        
        // Search button
        const searchBtn = document.getElementById('admin-search-btn');
        if (searchBtn) {
            searchBtn.addEventListener('click', () => {
                const input = document.getElementById('admin-player-id');
                if (input && input.value) {
                    nuiCallback('adminSearchPlayer', { serverId: parseInt(input.value) });
                } else {
                    showToast('Enter a server ID', 'warning');
                }
            });
        }
        
        // Search input enter key
        const searchInput = document.getElementById('admin-player-id');
        if (searchInput) {
            searchInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    const searchBtn = document.getElementById('admin-search-btn');
                    if (searchBtn) searchBtn.click();
                }
            });
        }
        
        // Refresh button
        const refreshBtn = document.getElementById('admin-refresh-btn');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => {
                if (state.adminPlayer) {
                    nuiCallback('adminRefreshPlayer', { targetIdentifier: state.adminPlayer.identifier });
                    showToast('Refreshing data...', 'info');
                }
            });
        }
        
        // Admin tabs
        document.querySelectorAll('.admin-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                switchAdminTab(tab.dataset.adminTab);
            });
        });
        
        // Add memory button
        const addMemoryBtn = document.getElementById('admin-add-memory-btn');
        if (addMemoryBtn) {
            addMemoryBtn.addEventListener('click', () => {
                if (!state.adminPlayer) {
                    showToast('Select a player first', 'warning');
                    return;
                }
                
                const type = document.getElementById('admin-memory-type').value;
                const desc = document.getElementById('admin-memory-desc').value.trim();
                const location = document.getElementById('admin-memory-location').value.trim();
                
                if (!desc) {
                    showToast('Enter a description', 'warning');
                    return;
                }
                
                nuiCallback('adminAddMemory', {
                    targetIdentifier: state.adminPlayer.identifier,
                    memoryType: type,
                    description: desc,
                    location: location
                });
                
                // Clear inputs
                document.getElementById('admin-memory-desc').value = '';
                document.getElementById('admin-memory-location').value = '';
                
                showToast('Memory added', 'success');
            });
        }
        
        // Add rumor button
        const addRumorBtn = document.getElementById('admin-add-rumor-btn');
        if (addRumorBtn) {
            addRumorBtn.addEventListener('click', () => {
                if (!state.adminPlayer) {
                    showToast('Select a player first', 'warning');
                    return;
                }
                
                const type = document.getElementById('admin-rumor-type').value;
                const content = document.getElementById('admin-rumor-content').value.trim();
                
                if (!content) {
                    showToast('Enter rumor content', 'warning');
                    return;
                }
                
                nuiCallback('adminAddRumor', {
                    targetIdentifier: state.adminPlayer.identifier,
                    rumorType: type,
                    content: content
                });
                
                // Clear input
                document.getElementById('admin-rumor-content').value = '';
                
                showToast('Rumor added', 'success');
            });
        }
        
        // Wipe button
        const wipeBtn = document.getElementById('admin-wipe-btn');
        if (wipeBtn) {
            wipeBtn.addEventListener('click', async () => {
                if (!state.adminPlayer) {
                    showToast('Select a player first', 'warning');
                    return;
                }
                
                const confirmed = await showConfirm(
                    'Wipe Player Data',
                    `Are you sure you want to wipe ALL data for ${state.adminPlayer.name}? This cannot be undone.`
                );
                
                if (confirmed) {
                    nuiCallback('adminWipePlayer', { targetIdentifier: state.adminPlayer.identifier });
                    showToast('Player data wiped', 'success');
                }
            });
        }
    }

    function setupRecentFacesEventListeners() {
        // Close button
        const closeBtn = document.getElementById('recent-faces-close');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                handleCloseRecentFaces();
                nuiCallback('closeRecentFaces');
            });
        }
    }

    // =========================================================================
    // Settings Panel
    // =========================================================================

    function handleOpenSettings(data) {
        console.log('[Lifeprint] Opening settings panel', data);
        
        state.settingsVisible = true;
        state.visible = false;
        
        // Hide other panels
        if (elements.app) elements.app.classList.add('nui-hidden');
        if (elements.adminContainer) elements.adminContainer.classList.add('nui-hidden');
        
        // Show settings panel
        const settingsContainer = document.getElementById('settings-container');
        if (settingsContainer) {
            settingsContainer.classList.remove('nui-hidden');
        }
        
        // Apply settings values to toggles
        const settings = data.settings || {
            face_reminders: true,
            proximity_memories: true,
            rumor_notifications: true,
            memory_popups: true
        };
        
        const faceToggle = document.getElementById('setting-face-reminders');
        const proximityToggle = document.getElementById('setting-proximity-memories');
        const rumorToggle = document.getElementById('setting-rumor-notifications');
        const popupToggle = document.getElementById('setting-memory-popups');
        
        if (faceToggle) faceToggle.checked = settings.face_reminders !== false;
        if (proximityToggle) proximityToggle.checked = settings.proximity_memories !== false;
        if (rumorToggle) rumorToggle.checked = settings.rumor_notifications !== false;
        if (popupToggle) popupToggle.checked = settings.memory_popups !== false;
    }

    function handleCloseSettings() {
        console.log('[Lifeprint] Closing settings panel');
        
        state.settingsVisible = false;
        
        const settingsContainer = document.getElementById('settings-container');
        if (settingsContainer) {
            settingsContainer.classList.add('nui-hidden');
        }
    }

    function handleSaveSettings() {
        const faceToggle = document.getElementById('setting-face-reminders');
        const proximityToggle = document.getElementById('setting-proximity-memories');
        const rumorToggle = document.getElementById('setting-rumor-notifications');
        const popupToggle = document.getElementById('setting-memory-popups');
        
        const settings = {
            face_reminders: faceToggle ? faceToggle.checked : true,
            proximity_memories: proximityToggle ? proximityToggle.checked : true,
            rumor_notifications: rumorToggle ? rumorToggle.checked : true,
            memory_popups: popupToggle ? popupToggle.checked : true
        };
        
        console.log('[Lifeprint] Saving settings:', settings);
        
        nuiCallback('saveSettings', settings);
        
        // Close settings after save
        setTimeout(() => {
            handleCloseSettings();
            nuiCallback('close');
        }, 300);
    }

    function setupSettingsEventListeners() {
        // Close button
        const closeBtn = document.getElementById('settings-close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                handleCloseSettings();
                nuiCallback('close');
            });
        }
        
        // Save button
        const saveBtn = document.getElementById('settings-save-btn');
        if (saveBtn) {
            saveBtn.addEventListener('click', handleSaveSettings);
        }
    }

    // =========================================================================
    // Character Avatar Handlers (Initials-based)
    // =========================================================================

    function handleUpdateAvatar(data) {
        console.log('[Lifeprint] Updating character avatar:', data);
        
        if (!data.initials) {
            console.warn('[Lifeprint] No initials provided for avatar');
            return;
        }
        
        // Check if we have a headshot texture to display
        const headshotSources = getHeadshotImageSources(data.headshotTxd);
        const hasHeadshot = headshotSources.length > 0;
        
        if (hasHeadshot) {
            console.log('[Lifeprint] Rendering headshot texture:', data.headshotTxd);
            
            // Show the image element with headshot texture
            if (elements.playerPhotoImg) {
                elements.playerPhotoImg.src = headshotSources[0];
                elements.playerPhotoImg.classList.remove('hidden');
                elements.playerPhotoImg.classList.add('headshot-texture');
                
                // Handle load error - fall back to initials
                elements.playerPhotoImg.onerror = function() {
                    if (headshotSources[1] && this.src !== headshotSources[1]) {
                        console.warn('[Lifeprint] Headshot primary failed, trying fallback URL');
                        this.src = headshotSources[1];
                        return;
                    }

                    console.error('[Lifeprint] Headshot texture failed to load:', this.src);
                    this.classList.add('hidden');
                    if (elements.photoPlaceholder) {
                        elements.photoPlaceholder.classList.remove('hidden');
                    }
                };
                
                // Hide placeholder since we're showing the image
                if (elements.photoPlaceholder) {
                    elements.photoPlaceholder.classList.add('hidden');
                }
            }
        } else {
            // No headshot - show initials placeholder
            console.log('[Lifeprint] No headshot available, showing initials');
            
            const placeholder = elements.photoPlaceholder;
            if (placeholder) {
                placeholder.classList.remove('hidden');
                
                // Find or create the initials element
                let initialsEl = placeholder.querySelector('.player-initials');
                if (!initialsEl) {
                    initialsEl = document.createElement('div');
                    initialsEl.className = 'player-initials';
                    placeholder.innerHTML = '';
                    placeholder.appendChild(initialsEl);
                }
                
                initialsEl.textContent = data.initials;
                initialsEl.style.background = data.color || 'linear-gradient(135deg, #6366f1, #8b5cf6)';
            }
            
            // Hide the image element (we're using initials)
            if (elements.playerPhotoImg) {
                elements.playerPhotoImg.classList.add('hidden');
            }
        }
        
        // Hide loading state
        if (elements.photoLoading) {
            elements.photoLoading.classList.add('hidden');
        }
        
        state.photoLoading = false;
    }

    function handleRefreshAvatar() {
        console.log('[Lifeprint] Refresh avatar requested');
        
        // Request new avatar from client
        nuiCallback('refreshPhoto', {});
    }

    function setupAvatarEventListeners() {
        // Refresh button (now refreshes initials/avatar)
        if (elements.photoRefreshBtn) {
            elements.photoRefreshBtn.addEventListener('click', handleRefreshAvatar);
        }
    }

    // =========================================================================
    // Initialization
    // =========================================================================

    function init() {
        console.log('[Lifeprint] Initializing application...');
        console.log('[Lifeprint] isDebug:', isDebug);
        
        // Initialize DOM elements after page load
        elements = {
            app: document.getElementById('app'),
            loadingScreen: document.getElementById('loading-screen'),
            mainContainer: document.getElementById('main-container'),
            closeBtn: document.getElementById('close-btn'),
            playerName: document.getElementById('player-name'),
            playerUpdated: document.getElementById('player-updated'),
            memoriesList: document.getElementById('memories-list'),
            relationshipsList: document.getElementById('relationships-list'),
            socialLinksList: document.getElementById('social-links-list'),
            socialWebGraph: document.getElementById('social-web-graph'),
            reputationList: document.getElementById('reputation-list'),
            reputationTags: document.getElementById('reputation-tags'),
            rumorsList: document.getElementById('rumors-list'),
            memoryModal: document.getElementById('memory-modal'),
            rumorModal: document.getElementById('rumor-modal'),
            toastContainer: document.getElementById('toast-container'),
            timelineFilters: document.getElementById('timeline-filters'),
            peopleSearch: document.getElementById('people-search'),
            characterRead: document.getElementById('character-read'),
            characterReadText: document.getElementById('character-read-text'),
            // Admin elements
            adminContainer: document.getElementById('admin-container'),
            // Memory popup
            memoryPopup: document.getElementById('memory-popup'),
            memoryPopupName: document.getElementById('memory-popup-name'),
            memoryPopupMemory: document.getElementById('memory-popup-memory'),
            memoryPopupNote: document.getElementById('memory-popup-note'),
            // Recent faces
            recentFacesPanel: document.getElementById('recent-faces-panel'),
            recentFacesList: document.getElementById('recent-faces-list'),
            // Debug panel
            debugPanel: document.getElementById('debug-panel'),
            debugPanelContent: document.getElementById('debug-panel-content'),
            debugCloseBtn: document.getElementById('debug-close-btn'),
            // Settings
            settingsContainer: document.getElementById('settings-container'),
            // Character photo
            playerPhoto: document.getElementById('player-photo'),
            playerPhotoImg: document.getElementById('player-photo-img'),
            photoPlaceholder: document.getElementById('photo-placeholder'),
            photoLoading: document.getElementById('photo-loading'),
            photoRefreshBtn: document.getElementById('photo-refresh-btn')
        };

        console.log('[Lifeprint] Initialized elements:', elements);

        // Check for missing critical elements
        if (!elements.loadingScreen || !elements.mainContainer) {
            console.error('[Lifeprint] Critical elements missing! loadingScreen:', elements.loadingScreen, 'mainContainer:', elements.mainContainer);
        }

        // Add debug class for browser preview styling
        if (isDebug) {
            document.body.classList.add('debug-mode');
        }

        setupEventListeners();
        setupNUIHandlers();
        setupAdminEventListeners();
        setupRecentFacesEventListeners();
        setupSettingsEventListeners();
        setupAvatarEventListeners();
        setupBrainEventListeners();

        // Debug mode: auto-open with mock data
        if (isDebug) {
            console.log('[Lifeprint] Debug mode - using mock data');
            setTimeout(() => {
                handleOpen(mockData.open);
            }, 150);
        } else {
            // In FiveM, set a timeout to show error if NUI opened but no data received
            setTimeout(() => {
                // Only show error if NUI was opened (visible) but still loading
                if (state.visible && state.loading) {
                    console.error('[Lifeprint] NUI opened but no data received after 3 seconds');
                    state.loading = false;
                    state.player = { name: 'Connection Error', identifier: 'error' };
                    if (elements.loadingScreen) elements.loadingScreen.classList.add('hidden');
                    if (elements.mainContainer) elements.mainContainer.classList.remove('hidden');
                    if (elements.playerName) elements.playerName.textContent = 'Connection Error';
                    showToast('Failed to load data. Check server console.', 'error');
                }
            }, 3000);
        }
    }

    // Start application
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
