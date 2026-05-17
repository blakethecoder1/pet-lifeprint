-- Lifeprint Configuration
-- The City Remembers
-- ============================================================================
-- A character memory, relationship, reputation, and rumor system
-- Supports: Standalone, QBCore, Qbox, ESX (auto-detected)
-- ============================================================================

Config = {}

-- ============================================================================
-- FRAMEWORK
-- ============================================================================
-- Options: "auto", "standalone", "qbcore", "qbox", "esx"
-- Auto-detect priority: qbx_core → qbox, qb-core → qbcore, es_extended → esx
Config.Framework = "auto"

-- ============================================================================
-- PERMISSIONS
-- ============================================================================
-- Method: "ace" | "framework" | "both"
-- ACE example: add_ace group.admin lifeprint.admin allow
Config.PermissionMethod = "both"
Config.ACEAdminGroup = "lifeprint.admin"

-- Framework-specific permission levels
Config.QBCorePermission = "admin"      -- "admin" or "god"
Config.ESXPermission = "superadmin"    -- "superadmin" or "admin"
Config.StandaloneAdminACE = "lifeprint.admin"

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
-- Use ox_lib if available, fallback to native GTA notifications
Config.UseOxLibNotify = true
Config.NativeNotifyDuration = 5000  -- ms

-- ============================================================================
-- UI
-- ============================================================================
Config.OpenCommand = "lifeprint"  -- Chat command to open NUI
Config.CloseKey = "ESC"           -- Hardcoded, documentation only
Config.LoadingScreenDuration = 6000  -- Milliseconds to show "Loading memories" screen

-- ============================================================================
-- MEMORIES
-- ============================================================================
Config.MaxMemoriesPerCharacter = 100

-- Memory types: { id, label, icon (inline SVG name) }
Config.MemoryTypes = {
    { id = "encounter",  label = "Encounter",  icon = "eye" },
    { id = "conflict",   label = "Conflict",   icon = "zap" },
    { id = "friendship", label = "Friendship", icon = "heart" },
    { id = "business",   label = "Business",   icon = "briefcase" },
    { id = "romantic",   label = "Romantic",   icon = "star" },
    { id = "betrayal",   label = "Betrayal",   icon = "skull" },
    { id = "rescue",     label = "Rescue",     icon = "shield" },
    { id = "crime",      label = "Crime",      icon = "lock" },
    { id = "kill",       label = "Kill",       icon = "crosshair" },
    { id = "death",      label = "Death",      icon = "x-circle" },
    { id = "npc_vehicle_theft", label = "Vehicle Theft", icon = "car" },
    { id = "npc_assault", label = "Assault",   icon = "fist" },
    { id = "npc_kill",   label = "NPC Kill",   icon = "skull" },
    { id = "gunshots",   label = "Gunshots",   icon = "bang" },
    { id = "reckless_driving", label = "Reckless Driving", icon = "zap" },
    { id = "drug_deal",  label = "Drug Deal",  icon = "pill" },
    { id = "injury",     label = "Injury",     icon = "heart" },
    { id = "vehicle_hit", label = "Vehicle Hit", icon = "car" },
    { id = "gunshot",    label = "Gunshot Wound", icon = "crosshair" },
    { id = "other",      label = "Other",      icon = "file" }
}

-- ============================================================================
-- RELATIONSHIPS
-- ============================================================================
-- Range: -100 (enemy) to +100 (family)
Config.RelationshipTypes = {
    -- Positive (0 to 100)
    stranger       = { min = 0,   max = 10,  label = "Stranger",       color = "#6B7280" },
    acquaintance   = { min = 11,  max = 30,  label = "Acquaintance",   color = "#9CA3AF" },
    friend         = { min = 31,  max = 60,  label = "Friend",         color = "#10B981" },
    close_friend   = { min = 61,  max = 80,  label = "Close Friend",   color = "#059669" },
    family         = { min = 81,  max = 100, label = "Family",         color = "#F59E0B" },
    -- Negative (-100 to -1)
    disliked       = { min = -10, max = -1,  label = "Disliked",       color = "#FCA5A5" },
    rival          = { min = -30, max = -11, label = "Rival",          color = "#F87171" },
    enemy          = { min = -100,max = -31, label = "Enemy",          color = "#EF4444" }
}

-- Point changes for integrations (use in AddRelationship calls)
Config.RelationshipPointChanges = {
    positive_interaction = 5,   negative_interaction = -5,
    major_positive = 15,        major_negative = -15,
    betrayal = -30,             rescue = 20
}

-- ============================================================================
-- REPUTATION
-- ============================================================================
-- Categories shown in Reputation tab
Config.ReputationCategories = {
    { id = "general",    label = "General Reputation", color = "#8B5CF6" },
    { id = "criminal",   label = "Criminal Standing",  color = "#EF4444" },
    { id = "business",   label = "Business Reputation", color = "#10B981" },
    { id = "law",        label = "Law Enforcement",    color = "#3B82F6" },
    { id = "medical",    label = "Medical Community",  color = "#EC4899" },
    { id = "underground",label = "Underground Scene",   color = "#F59E0B" }
}

-- Reputation ranges and labels
Config.ReputationRanges = {
    { min = -100, max = -75, label = "Infamous", tier = -4 },
    { min = -74, max = -50, label = "Notorious", tier = -3 },
    { min = -49, max = -25, label = "Disreputable", tier = -2 },
    { min = -24, max = -1, label = "Dubious", tier = -1 },
    { min = 0, max = 0, label = "Unknown", tier = 0 },
    { min = 1, max = 24, label = "Known", tier = 1 },
    { min = 25, max = 49, label = "Respected", tier = 2 },
    { min = 50, max = 74, label = "Honored", tier = 3 },
    { min = 75, max = 100, label = "Legendary", tier = 4 }
}

-- ============================================================================
-- REPUTATION COUNTERS & TAGS
-- ============================================================================
-- Counters track numerical events, tags are auto-generated at thresholds
Config.ReputationCounterTypes = { "arrests", "ems_visits", "crashes", "meetings", "helpful_actions", "suspicious_actions", "kills", "deaths", "npc_vehicle_thefts", "npc_assaults", "npc_kills", "gunshots_reported", "drug_deals", "injuries", "vehicle_hits", "gunshot_wounds" }

-- Tag thresholds: { threshold, label, priority (higher=more important), style }
Config.ReputationTagThresholds = {
    arrests = {
        { threshold = 1, label = "Has a Record",     priority = 3, style = "warning" },
        { threshold = 3, label = "Known Offender",   priority = 5, style = "danger" }
    },
    ems_visits = {
        { threshold = 3, label = "Frequent Patient", priority = 2, style = "info" }
    },
    crashes = {
        { threshold = 3, label = "Reckless Driver",  priority = 3, style = "warning" }
    },
    meetings = {
        { threshold = 5, label = "Well Connected",   priority = 4, style = "success" }
    },
    helpful_actions = {
        { threshold = 3, label = "Helpful Civilian", priority = 3, style = "success" }
    },
    suspicious_actions = {
        { threshold = 3, label = "Person of Interest", priority = 4, style = "warning" }
    },
    kills = {
        { threshold = 1, label = "Blood on Their Hands", priority = 5, style = "danger" },
        { threshold = 3, label = "Dangerous", priority = 6, style = "danger" }
    },
    deaths = {
        { threshold = 3, label = "Survivor", priority = 3, style = "info" },
        { threshold = 5, label = "Hard to Keep Down", priority = 4, style = "success" }
    },
    npc_vehicle_thefts = {
        { threshold = 2, label = "Car Thief", priority = 3, style = "warning" },
        { threshold = 5, label = "Grand Theft Auto", priority = 5, style = "danger" }
    },
    npc_assaults = {
        { threshold = 3, label = "Public Menace", priority = 4, style = "warning" },
        { threshold = 7, label = "Violent", priority = 6, style = "danger" }
    },
    npc_kills = {
        { threshold = 1, label = "Civilian Threat", priority = 5, style = "danger" },
        { threshold = 3, label = "City's Watching", priority = 7, style = "danger" }
    },
    gunshots_reported = {
        { threshold = 3, label = "Heat Magnet", priority = 4, style = "warning" },
        { threshold = 7, label = "Armed and Dangerous", priority = 6, style = "danger" }
    },
    drug_deals = {
        { threshold = 2, label = "Shady Dealings", priority = 3, style = "warning" },
        { threshold = 5, label = "Known Dealer", priority = 5, style = "danger" }
    },
    injuries = {
        { threshold = 5, label = "Battered", priority = 2, style = "warning" },
        { threshold = 10, label = "Scarred", priority = 4, style = "warning" }
    },
    vehicle_hits = {
        { threshold = 3, label = "Hit and Run Victim", priority = 2, style = "info" },
        { threshold = 7, label = "Road Rash", priority = 3, style = "warning" }
    },
    gunshot_wounds = {
        { threshold = 2, label = "Bullet Magnet", priority = 3, style = "warning" },
        { threshold = 5, label = "Walking Miracle", priority = 5, style = "success" }
    }
}

-- ============================================================================
-- Story Badges (Cosmetic RP Achievement System)
-- Players unlock cosmetic badges based on memories and reputation
-- These provide NO gameplay advantage - purely for RP flavor
-- ============================================================================

Config.Badges = {
    -- Master toggle for the badge system
    enabled = true,
    
    -- Notify player when a new badge is unlocked
    notifyOnUnlock = true,
    
    -- Badge definitions with unlock criteria
    -- Each badge has: id, label, description, icon, style, criteria
    definitions = {
        {
            id = 'survivor',
            label = 'Survivor',
            description = 'Cheated death multiple times',
            icon = 'heart-pulse',
            style = 'resilient',  -- blue/cyan tones
            criteria = {
                type = 'counter',
                counter = 'deaths',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'blood_on_hands',
            label = 'Blood on Their Hands',
            description = 'Has taken a life',
            icon = 'skull',
            style = 'dark',  -- red/black tones
            criteria = {
                type = 'counter',
                counter = 'kills',
                operator = '>=',
                value = 1
            }
        },
        {
            id = 'hospital_regular',
            label = 'Hospital Regular',
            description = 'Frequently visits Pillbox',
            icon = 'plus-circle',
            style = 'medical',  -- green/white
            criteria = {
                type = 'counter',
                counter = 'ems_visits',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'known_around_town',
            label = 'Known Around Town',
            description = 'Built many connections',
            icon = 'users',
            style = 'social',  -- purple/violet
            criteria = {
                type = 'relationship_count',
                operator = '>=',
                value = 10
            }
        },
        {
            id = 'face_collector',
            label = 'Face Collector',
            description = 'Remembers many faces',
            icon = 'camera',
            style = 'collector',  -- amber/gold
            criteria = {
                type = 'face_memory_count',
                operator = '>=',
                value = 5
            }
        },
        {
            id = 'bad_blood',
            label = 'Bad Blood',
            description = 'Has several enemies',
            icon = 'frown',
            style = 'negative',  -- crimson
            criteria = {
                type = 'negative_relationships',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'trusted_contact',
            label = 'Trusted Contact',
            description = 'Has earned many trusts',
            icon = 'handshake',
            style = 'trusted',  -- teal/green
            criteria = {
                type = 'positive_relationships',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'city_ghost',
            label = 'City Ghost',
            description = 'Moves through the city unnoticed',
            icon = 'ghost',
            style = 'ghost',  -- gray/silver
            criteria = {
                type = 'composite',
                conditions = {
                    { type = 'rumor_count', operator = '==', value = 0 },
                    { type = 'total_activity', operator = '<=', value = 5 }
                },
                requireAll = true
            }
        }
    },
    
    -- Badge notification templates
    notificationTemplates = {
        "New badge unlocked: {badge}!",
        "Your Lifeprint earned a new mark: {badge}",
        "The city recognizes your story. Badge unlocked: {badge}",
        "A new chapter in your Lifeprint: {badge}"
    }
}

-- ============================================================================
-- City Nicknames (Dynamic RP Identity System)
-- Players earn a city nickname based on their reputation and memories
-- ============================================================================

Config.CityNicknames = {
    -- Master toggle for the nickname system
    enabled = true,
    
    -- Notify player when their city nickname changes
    notifyOnChange = true,
    
    -- Nickname rules evaluated in order (first match wins)
    -- Higher priority = evaluated first
    rules = {
        {
            id = 'the_menace',
            nickname = 'The Menace',
            description = 'Known for taking lives',
            priority = 10,
            style = 'danger',  -- red tones
            criteria = {
                type = 'counter',
                counter = 'kills',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'trouble_magnet',
            nickname = 'Trouble Magnet',
            description = 'Frequently in trouble with the law',
            priority = 9,
            style = 'warning',  -- orange/yellow
            criteria = {
                type = 'counter',
                counter = 'arrests',
                operator = '>=',
                value = 3
            }
        },
        {
            id = 'the_survivor',
            nickname = 'The Survivor',
            description = 'Has cheated death many times',
            priority = 8,
            style = 'resilient',  -- cyan/blue
            criteria = {
                type = 'counter',
                counter = 'deaths',
                operator = '>=',
                value = 5
            }
        },
        {
            id = 'pillbox_regular',
            nickname = 'Pillbox Regular',
            description = 'Well known at the hospital',
            priority = 7,
            style = 'medical',  -- green
            criteria = {
                type = 'counter',
                counter = 'ems_visits',
                operator = '>=',
                value = 5
            }
        },
        {
            id = 'the_helper',
            nickname = 'The Helper',
            description = 'Always lending a hand',
            priority = 6,
            style = 'success',  -- green
            criteria = {
                type = 'counter',
                counter = 'helpful_actions',
                operator = '>=',
                value = 5
            }
        },
        {
            id = 'the_socialite',
            nickname = 'The Socialite',
            description = 'Knows everyone in the city',
            priority = 5,
            style = 'social',  -- purple
            criteria = {
                type = 'relationship_count',
                operator = '>=',
                value = 10
            }
        },
        {
            id = 'reckless_driver',
            nickname = 'Reckless',
            description = 'Known for dangerous driving',
            priority = 4,
            style = 'warning',
            criteria = {
                type = 'counter',
                counter = 'crashes',
                operator = '>=',
                value = 5
            }
        },
        {
            id = 'well_connected',
            nickname = 'Well Connected',
            description = 'Has many contacts around town',
            priority = 3,
            style = 'info',  -- blue
            criteria = {
                type = 'counter',
                counter = 'meetings',
                operator = '>=',
                value = 8
            }
        },
        {
            id = 'the_ghost',
            nickname = 'The Ghost',
            description = 'Moves through the city unnoticed',
            priority = 1,  -- lowest priority, fallback
            style = 'ghost',  -- gray/silver
            criteria = {
                type = 'composite',
                conditions = {
                    { type = 'rumor_count', operator = '==', value = 0 },
                    { type = 'total_activity', operator = '<=', value = 3 }
                },
                requireAll = true
            }
        }
    },
    
    -- Default nickname if no rules match
    defaultNickname = 'Newcomer',
    defaultStyle = 'neutral',
    
    -- Notification templates when nickname changes
    notificationTemplates = {
        "The city has a new name for you: {nickname}",
        "Word on the street is they're calling you {nickname} now.",
        "Your reputation precedes you. They call you {nickname}.",
        "The city whispers your new name: {nickname}",
        "You're now known around town as {nickname}."
    },
    
    -- Flavor text for nickname header display
    headerFormats = {
        default = '"{nickname}"',  -- Standard quote format
        titled = '{nickname}'       -- Just the nickname
    }
}

-- ============================================================================
-- Reputation Change Notifications
-- Notify players when they gain new reputation tags
-- ============================================================================

Config.ReputationNotifications = {
    -- Master toggle for reputation change notifications
    enabled = true,
    
    -- Notification templates for new tags
    -- {tag} is replaced with the tag label
    templates = {
        "Reputation changed: {tag}",
        "New Lifeprint trait unlocked: {tag}",
        "The city is starting to remember you as {tag}.",
        "Your reputation has shifted. People now see you as {tag}.",
        "Word spreads through the city: you're now known as {tag}."
    },
    
    -- Notification templates by tag style
    styleTemplates = {
        danger = {
            "Your Lifeprint darkens. The city fears you as {tag}.",
            "A shadow falls on your reputation. You're now known as {tag}.",
            "The whispers change. They're calling you {tag}."
        },
        warning = {
            "Caution spreads through the city. You're now {tag}.",
            "Your Lifeprint shifts uneasily. People see you as {tag}.",
            "Attention grows. The city marks you as {tag}."
        },
        success = {
            "Your Lifeprint glows brighter. You've earned the title {tag}.",
            "Good word spreads. People are calling you {tag}.",
            "The city smiles on you. You're now known as {tag}."
        },
        info = {
            "Your Lifeprint records a new chapter: {tag}.",
            "The city takes note. You're marked as {tag}.",
            "A new pattern emerges in your Lifeprint: {tag}."
        }
    },
    
    -- Only notify for tags with this minimum priority (higher = more important)
    minPriority = 1,
    
    -- Cooldown between notifications (seconds)
    cooldown = 60,
    
    -- Whether to update the Reputation tab live if UI is open
    liveUpdate = true
}

-- ============================================================================
-- Journal Update Notifications
-- Notify players when their Lifeprint is updated
-- ============================================================================

Config.JournalNotifications = {
    -- Master toggle for journal notifications
    enabled = true,
    
    -- Individual notification toggles
    showMemoryAdded = true,
    showRelationshipUpdated = true,
    showRumorAdded = true,
    showReputationChanged = true,
    
    -- Notification message templates
    -- {type} = memory/relationship/rumor/reputation
    -- {name} = target name (for relationships)
    -- {label} = relationship type label
    templates = {
        memoryAdded = {
            "Lifeprint updated: New memory added.",
            "Your Lifeprint captures a new moment.",
            "A new chapter is written in your Lifeprint.",
            "Your story grows. A memory is recorded."
        },
        relationshipUpdated = {
            "Relationship updated: {name} is now {label}.",
            "Your connection with {name} has evolved to {label}.",
            "Lifeprint updated: {name} — {label}.",
            "You now know {name} as {label}."
        },
        rumorAdded = {
            "New rumor added to your Lifeprint.",
            "Whispers circulate. A new rumor is recorded.",
            "The city's gossip reaches your Lifeprint.",
            "Your Lifeprint captures a new rumor."
        },
        reputationChanged = {
            "Your story changed.",
            "Your Lifeprint shifts.",
            "The city's perception of you has changed.",
            "A new pattern emerges in your Lifeprint."
        },
        demoGenerated = {
            "Lifeprint demo profile generated."
        }
    },
    
    -- Cooldown between similar notifications (seconds)
    cooldown = 30,
    
    -- Batch notifications during demo generation
    batchDemoNotifications = true,
    
    -- Whether to refresh affected tab if UI is open
    liveUpdate = true,
    
    -- Toast duration in milliseconds
    duration = 4000
}

-- ============================================================================
-- Immersive RP Flavor Text
-- Random text pools for notification triggers
-- ============================================================================

Config.FlavorText = {
    -- Master toggle for flavor text system
    enabled = true,
    
    -- Memory surfaced (location-based or relationship proximity trigger)
    memorySurfaced = {
        "A memory pulls at the back of your mind.",
        "Something about this feels familiar.",
        "Your Lifeprint stirs.",
        "A fragment of the past surfaces.",
        "The city whispers something you'd forgotten.",
        "Your mind drifts to an old memory.",
        "Something here tugs at your recollection.",
        "The past breathes near."
    },
    
    -- Face recognized (seeing a remembered person)
    faceRecognized = {
        "You know this face.",
        "A familiar face crosses your path.",
        "You remember them.",
        "Recognition flickers in your mind.",
        "Your Lifeprint echoes with recognition.",
        "That face isn't a stranger.",
        "You've seen them before.",
        "A memory takes shape behind their eyes."
    },
    
    -- Dangerous person nearby (negative relationship score)
    dangerousNearby = {
        "Your gut tells you to be careful.",
        "Bad history walks nearby.",
        "Someone with a dark past is close.",
        "Your instincts bristle.",
        "The air feels heavier around them.",
        "You remember why you don't trust them.",
        "Tread carefully—they're near.",
        "Old wounds ache in their presence."
    },
    
    -- Trusted person nearby (positive relationship score)
    trustedNearby = {
        "A friendly face in the crowd.",
        "Someone you trust is nearby.",
        "Your Lifeprint glows faintly.",
        "Good company is close.",
        "The city feels a little warmer.",
        "You sense an ally nearby.",
        "Someone with good history is here.",
        "A welcome presence approaches."
    },
    
    -- Old location revisited (location memory trigger)
    locationRevisited = {
        "You've been here before.",
        "This place holds a memory.",
        "The walls remember you.",
        "Your footsteps echo the past.",
        "Something happened here.",
        "This ground knows your story.",
        "A chapter of your Lifeprint was written here.",
        "The city recalls what transpired."
    },
    
    -- Rumor received
    rumorReceived = {
        "Whispers reach your ears.",
        "The city murmurs.",
        "Something is being said about you.",
        "A rumor takes root.",
        "Gossip travels fast in Los Santos.",
        "Word on the street finds you.",
        "The rumor mill turns.",
        "Someone's been talking."
    },
    
    -- Reputation changed
    reputationChanged = {
        "Your name carries weight now.",
        "The city's opinion shifts.",
        "Your Lifeprint reshapes.",
        "Something has changed in how they see you.",
        "Your story takes a new turn.",
        "The city adjusts its gaze.",
        "A new mark on your record.",
        "Your presence in Los Santos evolves."
    },
    
    -- Death memory (you died)
    deathMemory = {
        "Everything went dark.",
        "Your Lifeprint captured your final moment.",
        "The city witnessed your end.",
        "A chapter closes in blood.",
        "Los Santos claimed another.",
        "The lights faded to black.",
        "Your story paused—at the edge of a blade.",
        "Death's cold hand touched you."
    },
    
    -- Kill memory (you killed someone)
    killMemory = {
        "A life ended by your hand.",
        "Your Lifeprint darkens.",
        "The weight of survival settles in.",
        "Blood on your hands—another memory etched.",
        "Los Santos carves its marks deep.",
        "A shadow joins your Lifeprint.",
        "One less face in the city.",
        "The cost of the streets—paid."
    },
    
    -- EMS memory (medical treatment)
    emsMemory = {
        "White lights and steady hands.",
        "Your Lifeprint bears the scars of healing.",
        "Someone patched you up.",
        "A brush with mortality—treated.",
        "Pillbox knows your face now.",
        "Steady hands stitched your story back together.",
        "The city's healers left their mark.",
        "You walked away—but just barely."
    },
    
    -- Police memory (arrest or police interaction)
    policeMemory = {
        "The law caught up with you.",
        "Your Lifeprint carries a record.",
        "Blue lights in your rearview.",
        "Mission Row etched another page.",
        "Your file grows thicker.",
        "The department took notice.",
        "Your story now has a badge number.",
        "The system has your name."
    },
    
    -- Strength-based recognition (for high relationship strength)
    strongRecognition = {
        "You instantly recognize {name}.",
        "Their face is burned into your memory.",
        "There's no mistaking who this is.",
        "Your history with {name} runs deep.",
        "Years of history stare back at you.",
        "Your Lifeprint pulses—you know them well."
    },
    
    -- Faint recognition (low relationship strength)
    faintRecognition = {
        "Their face feels faintly familiar.",
        "You might have crossed paths before.",
        "A distant memory stirs.",
        "You think you've seen them somewhere.",
        "Your Lifeprint flickers with uncertainty.",
        "Recognition hovers just out of reach."
    }
}

-- Helper function to get random flavor text (used by server)
function GetFlavorText(category, placeholders)
    if not Config.FlavorText.enabled then return nil end
    if not Config.FlavorText[category] then return nil end
    
    local pool = Config.FlavorText[category]
    local text = pool[math.random(1, #pool)]
    
    -- Replace placeholders if provided
    if placeholders then
        for key, value in pairs(placeholders) do
            text = text:gsub('{' .. key .. '}', tostring(value))
        end
    end
    
    return text
end

-- Character Read paragraph templates
-- {positive_tags}, {negative_tags}, {neutral_tags} are placeholders
Config.CharacterReadTemplates = {
    -- Strong positive profile
    positive_strong = "Your Lifeprint paints the picture of a {positive_tags} character who's making a name for themselves in Los Santos. The city is taking notice of your good deeds.",
    
    -- Strong negative profile  
    negative_strong = "Your Lifeprint suggests a {negative_tags} individual with a history of police attention. The city keeps a watchful eye on your movements.",
    
    -- Mixed profile
    mixed = "Your Lifeprint suggests a {mixed_tags} character with both redeeming qualities and concerning patterns. The city's opinion of you remains divided.",
    
    -- Neutral/unknown profile
    neutral = "Your Lifeprint is still being written. The city doesn't know what to make of you yet - your actions will shape how you're remembered.",
    
    -- Well connected
    connected = "Your Lifeprint reveals someone who's {connected_tags}. You've built bridges across the city, and doors tend to open for you.",
    
    -- Danger/record
    record = "Your Lifeprint shows {record_tags}. Law enforcement has taken notice, and your reputation precedes you in certain circles."
}

-- Style mappings for tag chips (used in NUI)
Config.ReputationTagStyles = {
    success = { bg = "rgba(52, 211, 153, 0.15)", color = "#34d399", border = "rgba(52, 211, 153, 0.3)" },
    warning = { bg = "rgba(251, 191, 36, 0.15)", color = "#fbbf24", border = "rgba(251, 191, 36, 0.3)" },
    danger = { bg = "rgba(248, 113, 113, 0.15)", color = "#f87171", border = "rgba(248, 113, 113, 0.3)" },
    info = { bg = "rgba(96, 165, 250, 0.15)", color = "#60a5fa", border = "rgba(96, 165, 250, 0.3)" }
}

-- ============================================================================
-- Rumor Settings
-- ============================================================================

Config.Rumors = {
    -- Master toggle for rumor generation
    Enabled = true,
    
    -- Chance percentage for rumors to be created (0-100)
    Chance = 75,
    
    -- Maximum active rumors per character
    MaxPerCharacter = 20,
    
    -- Rumor expiration time (in game days, 0 = never expires)
    ExpirationDays = 7,
    
    -- Rumor spread multiplier (how many players can "hear" it)
    SpreadRadius = 3, -- Number of related players
    
    -- Duplicate prevention: check last N rumors for duplicate text
    DuplicateCheckCount = 10
}

-- Rumor types
Config.RumorTypes = {
    { id = "crime", label = "Crime", icon = "lock", color = "#EF4444" },
    { id = "secret", label = "Secret", icon = "eye-off", color = "#8B5CF6" },
    { id = "affair", label = "Personal", icon = "heart", color = "#EC4899" },
    { id = "business", label = "Business", icon = "briefcase", color = "#10B981" },
    { id = "conflict", label = "Conflict", icon = "zap", color = "#F59E0B" },
    { id = "achievement", label = "Achievement", icon = "trophy", color = "#3B82F6" },
    { id = "scandal", label = "Scandal", icon = "alert-triangle", color = "#EF4444" },
    { id = "hearsay", label = "Hearsay", icon = "message-circle", color = "#6B7280" }
}

-- ============================================================================
-- Rumor Templates by Category
-- Placeholders: {name}, {other}, {location}, {event}
-- ============================================================================

Config.RumorTemplates = {
    -- Police-related rumors
    police = {
        "Word on the street is {name} was picked up by LSPD near {location}.",
        "{name} was seen in cuffs downtown. People are talking.",
        "Heard {name} had a run-in with Officer {other}. Didn't end well.",
        "Someone saw {name} getting questioned at {location}. Interesting.",
        "LSPD's been asking around about {name}. Watch yourself."
    },
    
    -- EMS/Medical rumors
    ems = {
        "{name} was rushed to Pillbox the other night. Serious stuff.",
        "EMS were called for {name} at {location}. Hope they're okay.",
        "Heard {name} has been visiting the hospital a lot lately.",
        "{other} mentioned {name} needed medical attention. Wonder what happened.",
        "City's talking about another EMS visit for {name}."
    },
    
    -- Vehicle-related rumors
    vehicle = {
        "{name} crashed hard at {location}. Car's totaled.",
        "Saw {name}'s vehicle wrapped around a pole. Not pretty.",
        "Word is {name} can't drive worth a damn. Another crash.",
        "{other} was there when {name} wrecked their ride. Crazy scene.",
        "Another vehicle incident involving {name}. City keeps count."
    },
    
    -- Social/Meeting rumors
    social = {
        "{name} was seen talking with {other} at {location}. Interesting company.",
        "People noticed {name} making new connections downtown.",
        "Word is {name}'s been real friendly with certain crowds lately.",
        "Spotted {name} and {other} having a long conversation. Wonder what about.",
        "{name}'s been seen around {location} a lot. Building bridges?"
    },
    
    -- Suspicious activity rumors
    suspicious = {
        "Something's off about {name}. People are watching.",
        "{name}'s been asking too many questions around {location}.",
        "Heard {name} was lurking around {location} late at night.",
        "{other} says {name}'s been acting strange. Real strange.",
        "Word to the wise: keep an eye on {name}. Trust me."
    },
    
    -- Business-related rumors
    business = {
        "{name} closed a big deal at {location}. Money moving.",
        "Heard {name}'s business is booming. Or maybe not.",
        "{other} mentioned {name}'s got something cooking. Business-wise.",
        "City's talking about {name}'s latest venture. Interesting stuff.",
        "{name} was seen at {location} handling business. Making moves."
    },
    
    -- Trucking/Delivery rumors
    trucking = {
        "{name}'s been making deliveries all over the city. Hustling.",
        "Heard {name} wrecked a delivery run. Boss wasn't happy.",
        "{other} spotted {name} on a trucking job at {location}. Long hours.",
        "Word is {name}'s been running cargo non-stop. Getting tired.",
        "Another trucking run for {name} at {location}. Steady work."
    },
    
    -- DOT/Inspection rumors
    dot = {
        "{name} got flagged by DOT at {location}. Papers weren't right.",
        "Heard {name}'s vehicle passed inspection. Surprised everyone.",
        "DOT's been watching {name}. Something about their paperwork.",
        "{other} said {name} had a run-in with inspectors. Messy.",
        "Word is {name} got cited at {location}. Cost them."
    },
    
    -- Gang-related rumors
    gang = {
        "{name}'s been seen with the wrong crowd. Dangerous company.",
        "Word is {name}'s got connections to {other}. Watch yourself.",
        "People whisper about {name}'s affiliations. Block is talking.",
        "Heard {name} was at {location} with some interesting people.",
        "{name}'s name keeps coming up in certain circles. Street's watching."
    }
}

-- ============================================================================
-- Admin Commands
-- ============================================================================

Config.AdminCommands = {
    demo = "lpdemo",      -- Add demo data for current player
    wipe = "lpwipe",      -- Wipe all data for current player
    addmemory = "lpaddmemory"  -- Add a test memory
}

-- ============================================================================
-- Integration Settings
-- ============================================================================

-- Integration modules for external resources
-- Each integration can: add memory, update relationship, update reputation, create rumor
Config.Integrations = {
    Police = {
        enabled = true,
        -- Memory settings
        memoryType = "crime",
        -- Reputation settings
        reputationCategory = "law",
        reputationChange = -5,
        counterType = "arrests", -- increments counter
        -- Relationship settings (for officer involved)
        relationshipChange = -10,
        relationshipType = "adversary",
        -- Rumor settings
        createRumor = true,
        rumorType = "crime",
        rumorTemplates = {
            "Word on the street is {name} was picked up by LSPD.",
            "{name} was seen in cuffs near {location}.",
            "People are talking about {name}'s run-in with the law."
        }
    },
    
    EMS = {
        enabled = true,
        memoryType = "rescue",
        reputationCategory = "medical",
        reputationChange = 1, -- small positive for seeking medical help
        counterType = "ems_visits",
        relationshipChange = 5,
        relationshipType = "acquaintance",
        createRumor = false -- typically private
    },
    
    Jail = {
        enabled = true,
        memoryType = "crime",
        reputationCategory = "criminal",
        reputationChange = -10,
        counterType = "arrests",
        relationshipChange = -5,
        createRumor = true,
        rumorType = "crime",
        rumorTemplates = {
            "Rumor has it {name} did time at Bolingbroke.",
            "{name} was away for a while. People notice.",
            "Some say {name} has connections inside."
        }
    },
    
    Billing = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = -2, -- unpaid bills hurt reputation
        createRumor = false,
        -- Positive billing (payments)
        positiveReputationChange = 2
    },
    
    Gang = {
        enabled = true,
        memoryType = "encounter",
        reputationCategory = "underground",
        relationshipChange = 10, -- positive for allies
        relationshipType = "associate",
        counterType = "meetings",
        createRumor = true,
        rumorType = "secret",
        rumorTemplates = {
            "Word is {name} is getting close with certain crowds.",
            "People whisper about {name}'s new connections.",
            "{name} has been seen with interesting company lately."
        }
    },
    
    Business = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = 3,
        counterType = "meetings",
        relationshipChange = 5,
        relationshipType = "acquaintance",
        createRumor = false
    },
    
    Trucking = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = 2,
        counterType = "helpful_actions",
        createRumor = false,
        -- Crash/delivery failure
        crashReputationChange = -3,
        crashCounterType = "crashes"
    },
    
    DOT = {
        enabled = true,
        memoryType = "encounter",
        reputationCategory = "general",
        reputationChange = -2, -- inspection/citation
        counterType = "suspicious_actions",
        createRumor = false,
        -- Clean inspection bonus
        cleanReputationChange = 2,
        cleanCounterType = "helpful_actions"
    }
}

-- ============================================================================
-- Automatic Tracking Settings
-- ============================================================================

-- Lightweight automatic tracking of player interactions
Config.AutoTracking = {
    -- Master toggles for each tracking type
    proximity = true,        -- Track nearby players for relationships
    vehicleCrash = true,     -- Track vehicle accidents
    injury = true,           -- Track significant injuries
    
    -- Proximity tracking (creates "Known Contact" relationships)
    proximityDistance = 3.0,     -- Meters within which to track
    proximityTime = 20,          -- Seconds of proximity required
    proximityCooldown = 86400,   -- 24 hours cooldown per pair (seconds)
    proximityCheckInterval = 2000, -- Check every 2 seconds (milliseconds)
    
    -- Vehicle crash tracking
    crashCooldown = 600,         -- 10 minutes cooldown (seconds)
    crashHealthThreshold = 30,   -- Health drop percentage to trigger
    crashVelocityThreshold = 20.0, -- Minimum velocity for impact detection
    crashCheckInterval = 1000,   -- Check every 1 second (milliseconds)
    
    -- Injury tracking
    injuryCooldown = 600,        -- 10 minutes cooldown (seconds)
    injuryHealthThreshold = 120, -- Health below this triggers (0-200 scale)
    injuryCheckInterval = 2000,  -- Check every 2 seconds (milliseconds)
    
    -- Memory/relationship settings for auto-tracking
    proximityRelationshipType = "acquaintance",
    proximityRelationshipValue = 10, -- "Known Contact" value
    crashMemoryType = "encounter",
    crashMemoryTitle = "Vehicle Incident",
    injuryMemoryType = "encounter",
    injuryMemoryTitle = "Injury"
}

-- ============================================================================
-- Memory Brain UI System
-- Visual brain that changes color based on player's story
-- ============================================================================

Config.MemoryBrain = {
    -- Master toggle for memory brain system
    enabled = true,
    
    -- Show mini brain icon in header showing dominant color
    showHeaderBrain = true,
    
    -- Animate the brain visualization
    animateBrain = true,
    
    -- Pulse effect when a major memory is added
    pulseOnMajorMemory = true,
    
    -- Memory classification rules
    -- Memories are classified into 4 categories based on their type
    classifications = {
        -- Good memories (green zone)
        good = {
            'friendship', 'helpful', 'business_positive', 'trusted', 
            'ems_helped', 'positive', 'rescue', 'romantic'
        },
        
        -- Bad memories (red zone)
        bad = {
            'death', 'kill', 'crime', 'arrest', 'npc_kill', 'npc_assault',
            'vehicle_theft', 'hostile', 'negative', 'betrayal', 'conflict',
            'npc_vehicle_theft', 'gunshots', 'reckless_driving', 'drug_deal'
        },
        
        -- Rumors (purple zone) - entries from lifeprint_rumors table
        rumors = {
            'rumor', 'city_whisper'
        },
        
        -- Other/neutral memories (yellow zone)
        other = {
            'social', 'encounter', 'vehicle', 'location', 'business', 
            'unknown', 'injury', 'vehicle_hit', 'gunshot'
        }
    },
    
    -- Brain Read paragraph templates based on dominant category
    brainReadTemplates = {
        good_dominant = {
            "Your Lifeprint is mostly positive. The city remembers your good deeds.",
            "Green dominates your Lifeprint. You've built a reputation for kindness.",
            "The city sees the best in you. Your memories shine with positive moments.",
            "Your story is written in green. The city remembers your generosity."
        },
        bad_dominant = {
            "Your memories are stained red. Bad choices are becoming part of your story.",
            "The city remembers your darker moments. Red bleeds through your Lifeprint.",
            "Your Lifeprint carries scars. The streets whisper of your past.",
            "Blood and shadows mark your story. The city watches with caution."
        },
        rumors_dominant = {
            "Purple dominates your Lifeprint. Rumors are spreading faster than facts.",
            "The city whispers your name. Your Lifeprint is clouded with hearsay.",
            "Your story is told by others. Purple shadows your every move.",
            "Rumors shape your identity. The city knows you through gossip."
        },
        other_dominant = {
            "Your story is balanced. The city has not decided who you are yet.",
            "Your Lifeprint is still taking shape. The city watches and waits.",
            "Neither hero nor villain. Your story is yet to be written.",
            "The city hasn't made up its mind about you. Your future is unwritten."
        },
        balanced = {
            "Your Lifeprint weaves all colors equally. A complex story unfolds.",
            "Every shade has its place in your story. The city sees the full picture.",
            "Your memories paint a balanced portrait. Neither saint nor sinner."
        },
        empty = {
            "Your Lifeprint is empty. The city doesn't know you yet.",
            "A blank page awaits. Your story has yet to begin.",
            "No memories recorded. The city has nothing to remember."
        }
    },
    
    -- Notification templates for brain updates
    notificationTemplates = {
        "Memory Brain updated: {category} memory added.",
        "Your Lifeprint shifts. A new {category} memory.",
        "The city remembers. {category} memory recorded.",
        "Your story grows. {category} memory added to your Lifeprint."
    }
}

-- ============================================================================
-- DEBUG
-- ============================================================================
Config.Debug = false          -- Set to true ONLY for development/troubleshooting
Config.DebugCommands = true   -- Allow admin debug commands like /lpdebug
Config.LogLevel = "info"      -- "error", "warn", "info", "debug"

-- Debug command permission (ACE or framework)
Config.DebugPermission = 'lifeprint.admin'

-- ============================================================================
-- Performance Settings
-- ============================================================================

Config.Performance = {
    -- Client tracking intervals (milliseconds)
    proximityInterval = 2000,      -- Proximity check every 2s
    healthCheckInterval = 2000,    -- Health/injury check every 2s
    vehicleCheckInterval = 1000,   -- Vehicle crash check every 1s
    faceMemoryCheckInterval = 3000, -- Face memory proximity every 3s
    keyHandlerInterval = 100,      -- ESC key check every 100ms (not every frame)
    
    -- UI refresh cooldown (milliseconds)
    uiRefreshCooldown = 500,       -- Minimum time between UI data refreshes
    
    -- Server query limits (max rows returned)
    maxTimelineEntries = 50,       -- Max memories returned
    maxRumors = 25,                -- Max rumors returned
    maxRelationships = 50,         -- Max relationships returned
    
    -- Cache settings
    identifierCacheTTL = 300,      -- Seconds to cache player identifiers
    clearCacheOnDrop = true        -- Clear caches when player disconnects
}

-- ============================================================================
-- Face Memory Feature
-- ============================================================================

Config.FaceMemory = {
    -- Master toggle for face memory system
    enabled = true,
    
    -- Maximum distance to remember a face (meters)
    maxDistance = 5.0,
    
    -- Distance at which walk-by reminders trigger (meters)
    reminderDistance = 8.0,
    
    -- Cooldown between reminders for same target (seconds)
    reminderCooldown = 900,  -- 15 minutes
    
    -- How often to check for nearby remembered faces (milliseconds)
    checkInterval = 3000,  -- 3 seconds
    
    -- Memory type used for face memories
    memoryType = "encounter",
    
    -- Relationship type for face memories
    relationshipType = "remembered_face",
    
    -- Ped Headshot Settings (in-game photos)
    usePedHeadshot = true,       -- Capture real in-game headshots
    headshotTimeout = 3000,      -- Max wait time for headshot (milliseconds)
    fallbackToInitials = true    -- Show initials if headshot fails
}

-- ============================================================================
-- Face Photo Feature
-- Allows players to save photos/avatars for remembered faces
-- ============================================================================

Config.FacePhoto = {
    -- Master toggle for face photo system
    enabled = true,
    
    -- Maximum distance to set a face photo (meters)
    maxDistance = 5.0,
    
    -- Allow external URLs for photos (if false, only allow internal references)
    allowUrls = true,
    
    -- Maximum URL length
    maxUrlLength = 500,
    
    -- Supported URL protocols (if allowUrls is true)
    allowedProtocols = { "http://", "https://", "nui://" }
}

-- ============================================================================
-- Memory Pulse Popup
-- Cinematic notification when near someone with shared history
-- ============================================================================

Config.MemoryPulse = {
    -- Master toggle for memory pulse system
    enabled = true,
    
    -- Distance at which popup triggers (meters)
    distance = 8.0,
    
    -- Cooldown per target (seconds) - prevents spam
    cooldown = 900,  -- 15 minutes
    
    -- How often to check for nearby relationships (milliseconds)
    checkInterval = 3000,  -- 3 seconds
    
    -- Auto-hide duration (milliseconds)
    autoHideDuration = 6000,  -- 6 seconds
    
    -- Sound toggle (no external assets required)
    sound = false,
    
    -- Memory strength labels (displayed in popup)
    strengthLabels = {
        { min = 1, max = 2, label = "Faint Memory" },
        { min = 3, max = 4, label = "Familiar Face" },
        { min = 5, max = 6, label = "Known Contact" },
        { min = 7, max = 8, label = "Strong History" },
        { min = 9, max = 10, label = "Unforgettable" }
    }
}

-- Legacy alias for backwards compatibility
Config.MemoryPopup = Config.MemoryPulse

-- ============================================================================
-- Recent Faces Feature
-- Temporary proximity tracking for saving face memories later
-- ============================================================================

Config.RecentFaces = {
    -- Master toggle for recent faces system
    enabled = true,
    
    -- Maximum entries to store in recent faces list
    maxEntries = 10,
    
    -- How long before entries expire (minutes)
    expireMinutes = 10,
    
    -- Distance at which players are detected (meters)
    detectionDistance = 10.0,
    
    -- How often to scan for nearby players (milliseconds)
    scanInterval = 5000,  -- 5 seconds
    
    -- Minimum time near player before adding to list (milliseconds)
    minNearbyTime = 3000  -- 3 seconds
}

-- ============================================================================
-- Social Web Feature (Seen With)
-- Tracks who players are frequently seen near and generates social patterns
-- ============================================================================

Config.SocialWeb = {
    -- Master toggle for social web system
    enabled = true,
    
    -- Minimum proximity time before counting (seconds)
    minProximityTime = 30,  -- 30 seconds
    
    -- Distance at which proximity is tracked (meters)
    proximityDistance = 5.0,
    
    -- Cooldown between updates for same pair (seconds)
    cooldown = 1800,  -- 30 minutes
    
    -- How often to check for proximity (milliseconds)
    checkInterval = 3000,  -- 3 seconds
    
    -- Minimum seen_count to show in UI
    minSeenCountForUI = 2,
    
    -- Threshold for rumor generation
    rumorThreshold = 5,  -- Generate rumor when seen_count >= 5
    
    -- Maximum social links to return in UI
    maxLinks = 20,
    
    -- Memory strength contribution (to relationships)
    memoryStrengthBonus = 1
}

-- ============================================================================
-- Combat Tracking
-- Tracks kills, attacks, and combat encounters
-- ============================================================================

Config.CombatTracking = {
    -- Master toggle for combat tracking
    enabled = true,
    
    -- Track NPC kills
    trackNPCKills = true,
    
    -- Track player kills (PvP)
    trackPlayerKills = true,
    
    -- Track attacks (not just kills)
    trackAttacks = false,  -- Can be spammy
    
    -- Cooldown between combat memories (seconds)
    killCooldown = 300,  -- 5 minutes
    attackCooldown = 60,  -- 1 minute
    
    -- How often to check for combat events (milliseconds)
    checkInterval = 500,  -- 0.5 seconds
    
    -- Memory settings
    killMemoryType = "conflict",
    killMemoryTitle = "Violent Encounter",
    
    -- Reputation changes
    npcKillReputationChange = -3,      -- Killing NPCs
    playerKillReputationChange = -10,  -- Killing players
    attackerReputationChange = -2,     -- Attacking
    
    -- Counter types
    npcKillCounter = "suspicious_actions",
    playerKillCounter = "suspicious_actions",
    
    -- Create rumors for player kills
    createRumorOnPlayerKill = true,
    playerKillRumorTemplates = {
        "Word on the street is {name} was involved in a violent incident.",
        "People are whispering about {name}. Something bad went down.",
        "{name}'s name came up in connection with some trouble downtown.",
        "Heard {name} was in a fight. Didn't end well for the other guy."
    }
}

-- ============================================================================
-- Death/Kill Tracking
-- Dedicated system for player deaths and kills with timeline integration
-- ONLY triggers on confirmed player death (not normal damage)
-- ============================================================================

Config.DeathTracking = {
    -- Master toggle for death/kill tracking
    enabled = true,
    
    -- Track when player dies
    trackDeaths = true,
    
    -- Track when player kills another player
    trackKills = true,
    
    -- Create rumors when kills happen
    createRumors = true,
    
    -- Cooldown between death/kill events (seconds) - prevents spam
    cooldown = 15,
    
    -- Memory type for death memories (fixed as 'death')
    deathMemoryType = "death",
    deathMemoryTitle = "You Died",
    
    -- Memory type for kill memories (fixed as 'kill')
    killMemoryType = "kill",
    killMemoryTitle = "Took a Life",
    
    -- Reputation changes
    deathReputationChange = 0,      -- Dying doesn't hurt reputation
    killReputationChange = -15,     -- Killing hurts reputation significantly
    
    -- Relationship changes for PvP kills
    killRelationshipChange = -25,   -- Major negative relationship
    killRelationshipType = "Deadly History",
    
    -- Rumor templates for kills
    killRumorTemplates = {
        "Word on the street is {name} took someone out near {location}.",
        "People are whispering. Someone didn't make it after crossing {name}.",
        "{name}'s hands aren't clean. The city's talking about what happened.",
        "Heard {name} was involved in something final. No witnesses though."
    }
}

-- ============================================================================
-- Non-Fatal Injury Tracking
-- Records injuries when player is hurt but does NOT die
-- If damage causes death, death/kill memory is created instead (no injury)
-- ============================================================================

Config.InjuryTracking = {
    -- Master toggle for injury tracking
    enabled = true,
    
    -- Minimum health loss to count as injury (0-200 scale, player max is 200)
    minHealthLoss = 25,
    
    -- Cooldown between injury events (seconds) - prevents spam
    cooldown = 300,  -- 5 minutes
    
    -- Individual injury type toggles
    trackVehicleHit = true,     -- Hit by vehicle
    trackGunshot = true,        -- Shot but survived
    trackMelee = true,          -- Melee injury
    trackExplosion = true,      -- Explosion injury
    trackFall = true,           -- Hard fall
    
    -- Memory type for injuries
    injuryMemoryType = "injury",
    
    -- Memory titles by injury type
    memoryTitles = {
        vehicle_hit = "Hit by Vehicle",
        gunshot = "Gunshot Wound",
        melee = "Assault Injury",
        explosion = "Explosion Injury",
        fall = "Hard Fall"
    },
    
    -- Memory descriptions (uses {location} placeholder)
    memoryDescriptions = {
        vehicle_hit = "You were struck by a vehicle near {location}.",
        gunshot = "You were shot and survived near {location}.",
        melee = "You were injured in a fight near {location}.",
        explosion = "You survived an explosion near {location}.",
        fall = "You were badly hurt from a fall near {location}."
    },
    
    -- Counter increments per injury type
    counterIncrements = {
        vehicle_hit = { injuries = 1, vehicle_hits = 1 },
        gunshot = { injuries = 1, gunshot_wounds = 1 },
        melee = { injuries = 1 },
        explosion = { injuries = 1 },
        fall = { injuries = 1 }
    },
    
    -- Check interval (milliseconds)
    checkInterval = 1000
}

-- ============================================================================
-- Custom Notifications
-- In-game glassmorphism notifications for Lifeprint events
-- ============================================================================

Config.Notifications = {
    -- Master toggle for custom notifications
    enabled = true,
    
    -- Duration for notifications (milliseconds)
    duration = 5000,
    
    -- Animation duration (milliseconds)
    animationDuration = 300,
    
    -- Position: "top-right", "top-left", "bottom-right", "bottom-left"
    position = "top-right",
    
    -- Max notifications on screen (queue system)
    maxVisible = 3,
    
    -- Queue delay between showing stacked notifications (milliseconds)
    queueDelay = 500,
    
    -- Notification types with their styles
    types = {
        info = { icon = "info", color = "#60a5fa" },
        success = { icon = "check", color = "#34d399" },
        warning = { icon = "alert", color = "#fbbf24" },
        error = { icon = "x", color = "#f87171" },
        memory = { icon = "book", color = "#a78bfa" },
        relationship = { icon = "users", color = "#f472b6" },
        reputation = { icon = "star", color = "#fbbf24" },
        rumor = { icon = "message", color = "#9ca3af" },
        face = { icon = "eye", color = "#c084fc" },
        location = { icon = "map-pin", color = "#22d3ee" }
    },
    
    -- Which events trigger notifications
    notifyOn = {
        memoryCreated = true,
        relationshipCreated = true,
        relationshipUpdated = true,
        reputationChanged = true,
        rumorHeard = true,
        faceRemembered = true,
        combatEvent = true,
        proximityMemory = true
    }
}

-- ============================================================================
-- Memory Notifications (Memory Surfaced)
-- Cinematic RP-friendly notifications when near people/places from the past
-- ============================================================================

Config.MemoryNotifications = {
    -- Master toggle for memory surfaced notifications
    enabled = true,
    
    -- Distance checks for different trigger types
    distances = {
        rememberedPlayer = 10.0,    -- Distance to detect remembered face
        relationshipHistory = 12.0, -- Distance to detect relationship
        importantLocation = 15.0    -- Distance to detect location memory
    },
    
    -- Cooldowns per trigger type (seconds)
    cooldowns = {
        rememberedPlayer = 600,     -- 10 minutes
        relationshipHistory = 900,  -- 15 minutes
        importantLocation = 1200,   -- 20 minutes
        rumorHeard = 1800,          -- 30 minutes
        reputationTag = 3600        -- 1 hour
    },
    
    -- How often to check for nearby triggers (milliseconds)
    checkInterval = 4000,
    
    -- Auto-hide duration (milliseconds)
    autoHideDuration = 5000,
    
    -- Notification templates (randomly selected)
    templates = {
        -- Face memory detected
        faceMemory = {
            "Memory surfaced: You recognize {name}.",
            "A face from your past is nearby. You remember {name}.",
            "Your Lifeprint stirs. You know this person: {name}.",
            "{name}. The name comes to you before you see them."
        },
        
        -- Relationship history detected
        relationshipHistory = {
            "You remember {name}. {relationshipNote}",
            "Your Lifeprint stirs. You have history with {name}.",
            "Someone from your past is nearby: {name}.",
            "The city remembers. You and {name} have crossed paths before."
        },
        
        -- Location memory detected
        locationMemory = {
            "This area feels familiar. Something happened here.",
            "Your Lifeprint whispers. {memoryTitle} took place nearby.",
            "This location stirs a memory: {memoryTitle}.",
            "Deja vu. Your past is written on these streets."
        },
        
        -- Rumor heard
        rumorHeard = {
            "Word on the street... {rumorSnippet}",
            "Your Lifeprint picks up whispers: {rumorSnippet}",
            "The city talks. You hear: {rumorSnippet}",
            "A rumor reaches your ears: {rumorSnippet}"
        },
        
        -- Reputation tag change
        reputationTag = {
            "Your reputation shifts. The city now sees you as: {tag}",
            "Your Lifeprint grows. You've earned a new label: {tag}",
            "People are talking. They call you: {tag}",
            "The city's opinion of you has changed: {tag}"
        }
    },
    
    -- Strength-based messages (for relationship strength levels)
    strengthMessages = {
        strong = {
            "You instantly recognize {name}. Unforgettable.",
            "Your heart quickens. {name} is near.",
            "No mistaking it. {name} is close by."
        },
        moderate = {
            "A familiar presence. You think it's {name}.",
            "Someone you know is nearby... yes, {name}.",
            "Your instincts say {name} is close."
        },
        faint = {
            "A distant memory surfaces. You might know someone nearby.",
            "Your Lifeprint flickers. Someone from your past?",
            "A feeling of recognition, but who?"
        }
    }
}

-- ============================================================================
-- Memory Pulse (Immersive Feedback)
-- Cinematic screen-edge pulse and notification scaling
-- ============================================================================

Config.MemoryPulse = {
    -- Master toggle for memory pulse effects
    enabled = true,
    
    -- Screen-edge pulse effect (subtle glow from edges)
    screenPulse = true,
    
    -- Sound toggle (requires local sound file, skips safely if missing)
    sound = false,
    
    -- Duration for pulse effects (milliseconds)
    duration = 5000,
    
    -- Only show screen pulse for major/lifechanging memories
    majorOnlyPulse = true,
    
    -- Pulse intensity settings per memory importance
    intensity = {
        minor = {
            toast = true,           -- Show toast notification
            glow = false,           -- No glow effect
            pulse = false,          -- No screen pulse
            sound = false           -- No sound
        },
        notable = {
            toast = true,           -- Show toast notification
            glow = true,            -- Subtle glow on toast
            pulse = false,          -- No screen pulse
            sound = false           -- No sound
        },
        major = {
            toast = true,           -- Show toast notification
            glow = true,            -- Glow on toast
            pulse = true,           -- Screen-edge pulse
            sound = false           -- No sound (unless enabled)
        },
        lifechanging = {
            toast = true,           -- Show toast notification
            glow = true,            -- Strong glow on toast
            pulse = true,           -- Stronger screen pulse
            sound = false,          -- No sound (unless enabled)
            specialText = "Major Memory Surfaced"  -- Special header text
        }
    },
    
    -- Importance thresholds (what triggers each level)
    thresholds = {
        -- Minor: New encounter, brief interaction
        minor = { relationshipStrength = { min = 1, max = 2 } },
        -- Notable: Repeated contact, recognized face
        notable = { relationshipStrength = { min = 3, max = 5 } },
        -- Major: Close friend, enemy, significant event
        major = { relationshipStrength = { min = 6, max = 8 } },
        -- Lifechanging: Family, life/death, unforgettable
        lifechanging = { relationshipStrength = { min = 9, max = 10 } }
    },
    
    -- Pulse colors for different notification types
    colors = {
        memory = { primary = "#a78bfa", secondary = "rgba(167, 139, 250, 0.3)" },
        face = { primary = "#c084fc", secondary = "rgba(192, 132, 252, 0.3)" },
        relationship = { primary = "#f472b6", secondary = "rgba(244, 114, 182, 0.3)" },
        location = { primary = "#22d3ee", secondary = "rgba(34, 211, 238, 0.3)" },
        rumor = { primary = "#9ca3af", secondary = "rgba(156, 163, 175, 0.3)" },
        reputation = { primary = "#fbbf24", secondary = "rgba(251, 191, 36, 0.3)" }
    }
}

-- ============================================================================
-- Location-Based Memory Triggers
-- Remind players when they return to places where important memories occurred
-- ============================================================================

Config.LocationMemories = {
    -- Master toggle for location memory triggers
    enabled = true,
    
    -- Distance to trigger notification (in game units)
    distance = 35.0,
    
    -- Cooldown per memory location (seconds) - prevents spam
    cooldown = 1800,  -- 30 minutes
    
    -- Minimum importance level to trigger
    -- Options: "notable", "major", "lifechanging"
    -- Memories with relationshipStrength >= 3 will trigger
    minImportance = "notable",
    
    -- How often to check for nearby memory locations (milliseconds)
    checkInterval = 5000,  -- 5 seconds
    
    -- Maximum number of location memories to send to client
    maxLocationsToSend = 100,
    
    -- Notification templates for location memories
    templates = {
        "This area feels familiar. Something happened here.",
        "Your Lifeprint whispers. {memoryTitle} took place nearby.",
        "This location stirs a memory: {memoryTitle}.",
        "Deja vu. Your past is written on these streets.",
        "Memory surfaced: {memoryDescription}",
        "You remember this place. {memoryTitle}."
    },
    
    -- Memory types that should always trigger regardless of importance
    alwaysTriggerTypes = {
        "rescue",       -- EMS/hospital visits
        "crime",        -- Arrests, major crimes
        "death",        -- Death locations
        "conflict"      -- Major conflicts
    },
    
    -- Memory types to exclude from location triggers
    excludeTypes = {
        "encounter",    -- Too common
        "other"         -- Too generic
    }
}

-- ============================================================================
-- NPC Violence Tracking
-- Track harming/killing NPCs and shooting near NPCs
-- ============================================================================

Config.NPCViolence = {
    -- Master toggle for NPC violence tracking
    enabled = true,
    
    -- Individual event toggles
    trackAssault = true,       -- Damaging NPC peds
    trackKills = true,         -- Killing NPC peds
    trackGunshots = true,      -- Shooting near NPCs
    
    -- Distance for NPC to "witness" gunfire
    witnessDistance = 35.0,
    
    -- Cooldown between events (seconds) - prevents spam
    cooldown = 300,  -- 5 minutes
    
    -- Create rumors for witnessed events
    createRumors = true,
    
    -- How often to check for events (milliseconds)
    checkInterval = 1000,  -- 1 second
    
    -- Minimum health damage to count as assault (0-200 scale)
    minAssaultDamage = 10,
    
    -- Memory settings
    memories = {
        npc_assault = {
            title = "Civilian Harmed",
            description = "You harmed a local near {location}."
        },
        npc_kill = {
            title = "Civilian Killed",
            description = "A local died because of your actions near {location}."
        },
        gunshots = {
            title = "Shots Reported",
            description = "Locals heard gunfire connected to you near {location}."
        }
    },
    
    -- Reputation changes
    reputationChanges = {
        npc_assault = -15,
        npc_kill = -25,
        gunshots = -5
    },
    
    -- Counter increments
    counterIncrements = {
        npc_assault = { npc_assaults = 1, suspicious_actions = 1 },
        npc_kill = { npc_kills = 1, kills = 1, suspicious_actions = 1 },
        gunshots = { gunshots_reported = 1, suspicious_actions = 1 }
    },
    
    -- Rumor templates
    rumorTemplates = {
        npc_assault = {
            "Witnesses say {name} attacked a civilian near {location}.",
            "People are talking about {name} hurting someone near {location}.",
            "Locals reported an assault near {location}. {name} was mentioned."
        },
        npc_kill = {
            "Someone died near {location}. Word on the street points to {name}.",
            "A body was found near {location}. People are whispering about {name}.",
            "Tragic news from {location}. Locals suspect {name} was involved."
        },
        gunshots = {
            "Gunshots were heard near {location}. People think it was {name}.",
            "Locals reported loud bangs near {location}. {name} was seen in the area.",
            "Someone was shooting near {location}. {name}'s name came up."
        }
    }
}

-- ============================================================================
-- NPC Witness System
-- NPCs act as city witnesses - record memories, reputation, and rumors
-- when players commit suspicious or violent actions near NPCs
-- ============================================================================

Config.NPCWitness = {
    -- Master toggle for NPC witness system
    enabled = true,
    
    -- Distance (in game units) for NPC to "witness" an event
    witnessDistance = 35.0,
    
    -- Cooldown between witness events per type (seconds) - prevents spam
    cooldown = 300,  -- 5 minutes
    
    -- Require at least one NPC nearby to record the event
    requireNPCNearby = true,
    
    -- Create rumors for witnessed events
    createRumors = true,
    
    -- Individual event toggles
    trackVehicleTheft = true,      -- Stealing NPC vehicles
    trackNPCAssault = true,        -- Damaging NPCs
    trackNPCKill = true,           -- Killing NPCs
    trackGunshots = true,          -- Shooting near NPCs
    trackRecklessDriving = true,   -- Reckless driving near NPCs
    
    -- How often to check for NPCs (milliseconds)
    checkInterval = 2000,  -- 2 seconds
    
    -- Minimum NPC count required to trigger
    minWitnessCount = 1,
    
    -- Reputation changes for witnessed events
    reputationChanges = {
        vehicle_theft = -10,
        assault = -15,
        kill = -25,
        gunshot = -5,
        reckless_driving = -8
    },
    
    -- Memory titles for each event type
    memoryTitles = {
        npc_vehicle_theft = "Vehicle Stolen",
        npc_assault = "Assault Witnessed",
        npc_kill = "Witnessed Violence",
        gunshots = "Shots Fired",
        reckless_driving = "Reckless Driving",
        drug_deal = "Drug Deal Witnessed"
    },
    
    -- Rumor templates for NPC-witnessed events
    rumorTemplates = {
        npc_vehicle_theft = {
            "Locals say someone matching {name}'s description stole a vehicle near {location}.",
            "Witnesses report a vehicle theft in the {location} area. Suspect description is circulating.",
            "Word on the street: someone's driving around in a stolen ride from {location}."
        },
        npc_assault = {
            "People are talking about an assault near {location}.",
            "A witness saw someone get hurt at {location}. The attacker is being described.",
            "There was a disturbance at {location}. Someone got roughed up."
        },
        npc_kill = {
            "A witness saw something terrible near {location}. Someone didn't make it.",
            "People are whispering about a violent incident at {location}.",
            "The city's talking. Something fatal happened near {location}."
        },
        gunshots = {
            "Gunshots were reported in the {location} area. People are on edge.",
            "Someone was firing shots near {location}. Witnesses are shaken.",
            "A commotion with gunfire at {location}. No one knows who yet."
        },
        reckless_driving = {
            "A reckless driver caused chaos near {location}. Witnesses are upset.",
            "Someone was driving dangerously through {location}. Nearly hit pedestrians.",
            "Road rage incident reported at {location}. Car described as driving erratically."
        },
        drug_deal = {
            "Something shady went down near {location}. Looked like a deal.",
            "Witnesses saw a suspicious exchange at {location}. People are talking.",
            "Word is there was a handoff at {location}. Didn't look legal."
        }
    }
}

-- ============================================================================
-- NPC Vehicle Theft Tracking
-- Dedicated system for detecting when players take vehicles they don't own
-- ============================================================================

Config.NPCVehicleTheft = {
    -- Master toggle for vehicle theft tracking
    enabled = true,
    
    -- Time required driving before triggering (seconds)
    driveTimeRequired = 10,
    
    -- Distance required driving before triggering (meters)
    distanceRequired = 50.0,
    
    -- Cooldown between theft detections (seconds)
    cooldown = 600,
    
    -- Create a rumor when theft is detected
    createRumor = true,
    
    -- Require NPCs nearby to witness the theft
    requireWitness = true,
    
    -- Distance to check for NPC witnesses (meters)
    witnessDistance = 35.0,
    
    -- Minimum number of NPCs required to witness
    minWitnessCount = 1,
    
    -- Vehicle classes to ignore (never trigger for these)
    -- Classes: 0=Compacts, 1=Sedans, 2=SUVs, 3=Coupes, 4=Muscle, 5=Sports Classics
    -- 6=Sports, 7=Super, 8=Motorcycles, 9=Off-road, 10=Industrial, 11=Utility
    -- 12=Vans, 13=Cycles, 14=Boats, 15=Helicopters, 16=Planes, 17=Service
    -- 18=Emergency, 19=Military, 20=Commercial, 21=Trains
    ignoredClasses = {
        14, -- Boats
        15, -- Helicopters
        16, -- Planes
        17, -- Service
        18, -- Emergency (police, ambulance, fire)
        19, -- Military
        21  -- Trains
    },
    
    -- Specific vehicle models to ignore (by model name)
    -- Example: "police", "ambulance", "firetruck", "taxi", "bus"
    ignoredModels = {
        "police",
        "police2",
        "police3",
        "police4",
        "policeb",
        "policet",
        "ambulance",
        "firetruk",
        "lguard",
        "fbi",
        "fbi2",
        "sheriff",
        "sheriff2",
        "pranger",
        "riot",
        "policeold1",
        "policeold2",
        "pbus",
        "taxi",
        "bus",
        "coach",
        "trash",
        "trash2",
        "biff",
        "boxville",
        "mule",
        "mule2",
        "mule3",
        "pony",
        "pony2",
        "speedo",
        "speedo2",
        "burrito",
        "burrito2",
        "burrito3",
        "burrito4",
        "rumpo",
        "rumpo2",
        "rumpo3"
    },
    
    -- How often to check driving conditions (milliseconds)
    checkInterval = 1000,
    
    -- Memory settings
    memoryType = "npc_vehicle_theft",
    memoryTitle = "Vehicle Theft",
    memoryDescription = "You were seen taking a vehicle that was not yours near {location}.",
    
    -- Reputation changes
    reputationChange = -10,
    counterType = "npc_vehicle_thefts",
    secondaryCounterType = "suspicious_actions",
    
    -- Rumor template
    rumorTemplate = "Locals say someone matching {name}'s description stole a vehicle near {location}."
}
