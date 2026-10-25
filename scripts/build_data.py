#!/usr/bin/env python3
"""Builds the offline datasets bundled in the app.

    curl -sSLo /tmp/countries.json https://raw.githubusercontent.com/mledoze/countries/master/countries.json
    python3 scripts/build_data.py /tmp/countries.json

Base facts (names, capitals, currencies, languages, coordinates, flags) come from
mledoze/countries (ODbL). Travel extras (plugs, driving side, emergency numbers,
rough backpacker costs, tipping, best time to visit) are hand-curated, approximate,
and meant as a starting point - always double-check before you go.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources")

# Plug types by country (IEC letters).
PLUGS = {
    "GB": "G", "IE": "G", "MT": "G", "CY": "G", "HK": "G", "MY": "G", "SG": "G", "AE": "G", "QA": "G", "KE": "G",
    "UG": "G", "TZ": "D, G", "MU": "C, G", "LK": "D, G", "BN": "G", "MV": "C, D, G, J, K, L", "BH": "G", "OM": "C, G",
    "KW": "C, G", "SA": "G", "ZM": "C, D, G", "ZW": "D, G", "GH": "D, G", "NG": "D, G", "RW": "C, J", "MW": "G",
    "US": "A, B", "CA": "A, B", "MX": "A, B", "JP": "A, B", "TW": "A, B", "PH": "A, B, C", "CO": "A, B", "EC": "A, B",
    "PA": "A, B", "CR": "A, B", "GT": "A, B", "HN": "A, B", "NI": "A, B", "SV": "A, B", "BZ": "A, B, G", "CU": "A, B, C, L",
    "DO": "A, B", "PR": "A, B", "JM": "A, B", "VE": "A, B", "TH": "A, B, C, O", "VN": "A, C, D", "KH": "A, C, G",
    "LA": "A, B, C, E, F", "ID": "C, F", "MM": "C, D, F, G", "CN": "A, C, I", "KR": "C, F", "MN": "C, E",
    "IN": "C, D, M", "NP": "C, D, M", "BD": "A, C, D, G, K", "PK": "C, D", "BT": "C, D, F, G",
    "AU": "I", "NZ": "I", "FJ": "I", "PG": "I", "AR": "C, I", "UY": "C, F, I, L", "CL": "C, L", "BR": "C, N",
    "PE": "A, B, C", "BO": "A, C", "PY": "C", "ZA": "C, M, N", "NA": "D, M", "BW": "D, G, M", "MZ": "C, F, M",
    "IL": "C, H", "JO": "B, C, D, F, G, J", "EG": "C, F", "MA": "C, E", "TN": "C, E", "TR": "C, F", "GE": "C, F",
    "AM": "C, F", "AZ": "C, F", "UZ": "C, F", "KZ": "C, F", "KG": "C, F", "TJ": "C, F", "RU": "C, F", "UA": "C, F",
    "CH": "C, J", "LI": "C, J", "IT": "C, F, L", "SM": "C, F, L", "VA": "C, F, L", "DK": "C, E, F, K",
    "FR": "C, E", "BE": "C, E", "MC": "C, E, F", "PL": "C, E", "CZ": "C, E", "SK": "C, E",
    "IS": "C, F", "ET": "C, E, F, L", "SN": "C, D, E, K", "TT": "A, B", "BS": "A, B", "BB": "A, B", "MO": "D, G, M",
}
EUROPE_DEFAULT_PLUG = "C, F"

LEFT_DRIVING = set("""GB IE MT CY AU NZ JP TH MY SG ID IN NP LK BD PK BT BN TL HK MO ZA KE TZ UG ZM ZW MZ BW NA MW LS SZ MU
SC FJ PG SB TO WS KI TV NR JM BS BB TT GY SR AG DM GD KN LC VC IM JE GG FK MV""".split())

EMERGENCY = {
    "GB": "999 or 112", "IE": "112 or 999", "US": "911", "CA": "911", "MX": "911", "AU": "000 (112 from mobiles)",
    "NZ": "111", "TH": "191 police · 1669 ambulance · 1155 tourist police", "VN": "113 police · 115 ambulance · 114 fire",
    "KH": "117 police · 119 ambulance", "LA": "191 police · 195 ambulance", "ID": "112 · 110 police · 118 ambulance",
    "MY": "999", "SG": "999 police · 995 ambulance", "PH": "911", "MM": "199", "IN": "112", "NP": "100 police · 102 ambulance · 1144 tourist police",
    "LK": "119 police · 1990 ambulance", "BD": "999", "PK": "15 police · 1122 rescue", "JP": "110 police · 119 ambulance",
    "KR": "112 police · 119 ambulance", "CN": "110 police · 120 ambulance", "TW": "110 police · 119 ambulance", "HK": "999",
    "MN": "102 police · 103 ambulance", "PE": "105 police · 106 ambulance", "BO": "110 police · 118 ambulance",
    "EC": "911", "CO": "123", "CL": "133 police · 131 ambulance", "AR": "911 (Buenos Aires) · 107 ambulance",
    "BR": "190 police · 192 ambulance", "UY": "911", "PY": "911", "CR": "911", "PA": "911", "GT": "110 police · 1500 tourist assistance",
    "BZ": "911", "HN": "911", "NI": "118 police · 128 ambulance", "SV": "911", "CU": "106 police · 104 ambulance",
    "ZA": "10111 police · 10177 ambulance · 112 mobile", "KE": "999 or 112", "TZ": "112", "UG": "999 or 112", "MA": "19 police · 15 ambulance",
    "EG": "122 police · 123 ambulance · 126 tourist police", "TR": "112", "IL": "100 police · 101 ambulance", "JO": "911",
    "AE": "999 police · 998 ambulance", "FJ": "917 police · 911 ambulance", "NA": "10111", "BW": "999 police · 997 ambulance",
    "ZW": "999", "ZM": "999", "MZ": "119 police · 117 ambulance", "RW": "112", "ET": "991 police · 907 ambulance", "GE": "112",
    "IS": "112", "CH": "112", "NO": "112", "RU": "112", "UA": "112", "MV": "119 police · 102 ambulance", "QA": "999",
    "OM": "9999", "SA": "911", "BT": "113 police · 112 ambulance", "UZ": "102 police · 103 ambulance", "KZ": "112",
    "KG": "112", "DO": "911", "JM": "119 police · 110 ambulance", "PR": "911", "TT": "999 police · 990 fire/ambulance",
}
EU_112 = set("AT BE BG HR CZ DK EE FI FR DE GR HU IT LV LT LU MT NL PL PT RO SK SI ES SE AL BA ME MK RS MD AD MC SM LI XK".split())

# Rough backpacker spend per day in USD (hostel dorm, local food, some activities).
DAILY_USD = {
    "TH": 35, "VN": 30, "KH": 30, "LA": 30, "ID": 35, "MY": 40, "SG": 85, "PH": 40, "MM": 35, "IN": 25, "NP": 25,
    "LK": 35, "BD": 25, "PK": 25, "BT": 250, "MV": 90, "JP": 90, "KR": 70, "CN": 50, "TW": 60, "HK": 80, "MO": 80, "MN": 40,
    "AU": 85, "NZ": 85, "FJ": 60, "US": 120, "CA": 100, "MX": 45, "GT": 35, "BZ": 55, "HN": 40, "SV": 40, "NI": 35,
    "CR": 60, "PA": 55, "CU": 50, "DO": 50, "JM": 60, "PR": 90, "CO": 40, "EC": 40, "PE": 40, "BO": 30, "CL": 60,
    "AR": 45, "UY": 60, "PY": 40, "BR": 50, "VE": 40, "GB": 95, "IE": 95, "FR": 90, "ES": 70, "PT": 60, "IT": 85,
    "DE": 80, "NL": 95, "BE": 85, "LU": 95, "CH": 130, "AT": 85, "DK": 110, "SE": 95, "NO": 120, "FI": 95, "IS": 130,
    "PL": 50, "CZ": 55, "SK": 50, "HU": 50, "SI": 65, "HR": 70, "BA": 40, "RS": 40, "ME": 50, "AL": 40, "MK": 35,
    "GR": 65, "BG": 40, "RO": 45, "MD": 35, "UA": 35, "EE": 60, "LV": 55, "LT": 50, "MT": 75, "CY": 70, "TR": 45,
    "GE": 35, "AM": 35, "AZ": 40, "UZ": 30, "KZ": 35, "KG": 30, "TJ": 30, "MA": 35, "EG": 35, "TN": 35, "JO": 60,
    "IL": 100, "AE": 100, "OM": 80, "QA": 100, "ZA": 50, "NA": 60, "BW": 70, "ZW": 50, "ZM": 50, "MZ": 45, "MW": 35,
    "TZ": 50, "KE": 50, "UG": 40, "RW": 50, "ET": 35, "MG": 35, "MU": 70, "SN": 45, "GH": 40,
}

TIPPING = {
    "US": "Expected: 18–22% in restaurants, $1–2 per drink.", "CA": "Expected: 15–20% in restaurants.",
    "MX": "10–15% in restaurants; small change for helpers.", "GB": "10–12.5% if service isn't included.",
    "IE": "10–15% for good table service.", "TH": "Not expected; round up or leave 20–50 baht.",
    "VN": "Not expected, appreciated for tours and good service.", "KH": "Not expected; $1–2 for guides is kind.",
    "LA": "Not expected; round up.", "ID": "Not expected; 5–10% at nicer places (often service charge).",
    "MY": "Not expected; service charge often added.", "SG": "Not expected; 10% service charge is common.",
    "PH": "Around 10% if no service charge.", "IN": "About 10% in restaurants.", "NP": "About 10%; tip trekking guides/porters.",
    "LK": "About 10% if not added.", "JP": "Never tip - it can cause confusion.", "KR": "Not customary.",
    "CN": "Not customary.", "TW": "Not customary; 10% service charge at some restaurants.", "AU": "Not expected; 10% for great service.",
    "NZ": "Not expected.", "FJ": "Not expected.", "PE": "About 10% in restaurants.", "BO": "Round up / 5–10%.",
    "CO": "10% is usually added - you'll be asked.", "EC": "10% service is usually included.", "CL": "10% is suggested on the bill.",
    "AR": "About 10% in restaurants, in cash.", "BR": "10% service usually included.", "CR": "10% service included by law.",
    "GT": "About 10%.", "FR": "Service included; round up for good service.", "ES": "Not expected; round up or 5–10%.",
    "PT": "5–10% for good service.", "IT": "Coperto/service often included; round up.", "DE": "Round up 5–10%.",
    "NL": "5–10% optional.", "GR": "Round up or 5–10%.", "HR": "About 10% for good service.", "TR": "5–10% in restaurants.",
    "MA": "Small tips widely expected (5–10%).", "EG": "Baksheesh expected for most services.", "ZA": "10–15% in restaurants.",
    "KE": "About 10%; tip safari guides.", "TZ": "Tip safari and Kilimanjaro crews generously.", "AE": "10–15% if not included.",
    "IS": "Not expected.", "CH": "Included; round up.", "CZ": "Round up ~10%.", "HU": "10–15% (check if service added).",
    "PL": "About 10%.", "GE": "10% often added.", "JO": "About 10%.", "IL": "10–15% in restaurants.",
}

BEST_TIME = {
    "TH": "Nov–Mar (cool & dry). Gulf islands best Jan–Aug.", "VN": "North: Oct–Apr · Centre: Feb–Aug · South: Dec–Apr.",
    "KH": "Nov–Apr (dry season).", "LA": "Nov–Apr.", "ID": "Apr–Oct (dry season).", "MY": "West coast: Dec–Apr · East coast: Mar–Oct.",
    "SG": "Year-round; Feb–Apr is driest.", "PH": "Dec–May.", "MM": "Nov–Feb.", "IN": "Oct–Mar for most of the country.",
    "NP": "Oct–Nov and Mar–Apr for trekking.", "LK": "South/west: Dec–Mar · East: Apr–Sep.", "JP": "Mar–May (blossom) and Oct–Nov.",
    "KR": "Apr–Jun and Sep–Nov.", "CN": "Apr–May and Sep–Oct.", "TW": "Oct–Dec and Mar–Apr.", "AU": "Sep–Nov and Mar–May (north: May–Oct).",
    "NZ": "Dec–Feb summer; Jun–Aug for skiing.", "FJ": "May–Oct (dry).", "US": "Depends on region - spring & autumn are great.",
    "CA": "Jun–Sep; Dec–Mar for snow.", "MX": "Dec–Apr (dry season).", "GT": "Nov–Apr.", "CR": "Dec–Apr (dry).",
    "PA": "Dec–Apr.", "CO": "Dec–Mar and Jul–Aug.", "EC": "Galápagos year-round; Andes Jun–Sep.", "PE": "May–Sep (Inca Trail dry season).",
    "BO": "May–Oct; salt flats mirror effect Jan–Mar.", "CL": "Patagonia: Nov–Mar · Atacama: year-round.", "AR": "Patagonia: Nov–Mar · Buenos Aires: Mar–May, Sep–Nov.",
    "BR": "Sep–Mar (varies by region).", "UY": "Dec–Mar.", "CU": "Nov–Apr.", "GB": "May–Sep.", "IE": "May–Sep.", "FR": "Apr–Jun and Sep–Oct.",
    "ES": "Apr–Jun and Sep–Oct.", "PT": "Apr–Jun and Sep–Oct.", "IT": "Apr–Jun and Sep–Oct.", "GR": "May–Jun and Sep–Oct.",
    "HR": "May–Jun and Sep.", "TR": "Apr–May and Sep–Nov.", "IS": "Jun–Aug; Sep–Mar for northern lights.", "NO": "Jun–Aug; winter for aurora.",
    "MA": "Mar–May and Sep–Nov.", "EG": "Oct–Apr.", "JO": "Mar–May and Sep–Nov.", "ZA": "May–Sep for safari; Nov–Mar for Cape Town.",
    "KE": "Jul–Oct (Great Migration) and Jan–Feb.", "TZ": "Jun–Oct; Jan–Feb for calving season.", "NA": "May–Oct.", "BW": "May–Oct.",
    "GE": "May–Jun and Sep–Oct.", "UZ": "Apr–Jun and Sep–Oct.", "KG": "Jun–Sep.", "MN": "Jun–Aug.", "AE": "Nov–Mar.", "MV": "Nov–Apr.",
}

GOVUK_SLUG = {
    "US": "usa", "KR": "south-korea", "KP": "north-korea", "CZ": "czech-republic", "CD": "democratic-republic-of-the-congo",
    "CG": "congo", "CI": "cote-d-ivoire", "TL": "timor-leste", "GM": "the-gambia", "VA": "italy", "PS": "the-occupied-palestinian-territories",
    "MK": "north-macedonia", "BA": "bosnia-and-herzegovina", "MM": "myanmar", "VN": "vietnam", "LA": "laos", "RU": "russia",
    "IR": "iran", "SY": "syria", "TW": "taiwan", "BO": "bolivia", "VE": "venezuela", "TZ": "tanzania", "FM": "micronesia",
    "BS": "bahamas", "NL": "netherlands", "AE": "united-arab-emirates", "PH": "philippines", "MV": "maldives", "TR": "turkey",
}

# Popular places for backpackers: name, country, lat, lon[, aliases]
PLACES = [
    # South-East Asia
    ("Bangkok", "TH", 13.7563, 100.5018), ("Chiang Mai", "TH", 18.7883, 98.9853), ("Chiang Rai", "TH", 19.9105, 99.8406),
    ("Pai", "TH", 19.3583, 98.4400), ("Phuket", "TH", 7.8804, 98.3923), ("Krabi", "TH", 8.0863, 98.9063),
    ("Koh Phangan", "TH", 9.7319, 100.0136, ["Ko Pha Ngan"]), ("Koh Samui", "TH", 9.5120, 100.0136), ("Koh Tao", "TH", 10.0956, 99.8404),
    ("Koh Lanta", "TH", 7.6250, 99.0790), ("Koh Phi Phi", "TH", 7.7407, 98.7784, ["Phi Phi"]), ("Ayutthaya", "TH", 14.3532, 100.5689),
    ("Kanchanaburi", "TH", 14.0228, 99.5328), ("Railay", "TH", 8.0110, 98.8380), ("Koh Chang", "TH", 12.0536, 102.3446),
    ("Sukhothai", "TH", 17.0078, 99.8230), ("Khao Sok", "TH", 8.9133, 98.5300), ("Koh Lipe", "TH", 6.4887, 99.3036),
    ("Hanoi", "VN", 21.0278, 105.8342), ("Ha Long Bay", "VN", 20.9101, 107.1839, ["Halong Bay", "Halong"]), ("Sapa", "VN", 22.3364, 103.8438, ["Sa Pa"]),
    ("Ninh Binh", "VN", 20.2506, 105.9745), ("Ha Giang", "VN", 22.8233, 104.9836), ("Hue", "VN", 16.4637, 107.5909),
    ("Hoi An", "VN", 15.8801, 108.3380), ("Da Nang", "VN", 16.0544, 108.2022), ("Da Lat", "VN", 11.9404, 108.4583, ["Dalat"]),
    ("Nha Trang", "VN", 12.2388, 109.1967), ("Ho Chi Minh City", "VN", 10.8231, 106.6297, ["Saigon"]), ("Phu Quoc", "VN", 10.2899, 103.9840),
    ("Phong Nha", "VN", 17.5900, 106.2830), ("Mui Ne", "VN", 10.9333, 108.2833), ("Mekong Delta", "VN", 10.0452, 105.7469, ["Can Tho"]),
    ("Phnom Penh", "KH", 11.5564, 104.9282), ("Siem Reap", "KH", 13.3671, 103.8448, ["Angkor Wat", "Angkor"]), ("Kampot", "KH", 10.6104, 104.1815),
    ("Koh Rong", "KH", 10.7140, 103.2390), ("Battambang", "KH", 13.0957, 103.2022), ("Sihanoukville", "KH", 10.6253, 103.5234),
    ("Luang Prabang", "LA", 19.8834, 102.1347), ("Vang Vieng", "LA", 18.9235, 102.4478), ("Vientiane", "LA", 17.9757, 102.6331),
    ("Nong Khiaw", "LA", 20.5667, 102.6167), ("4000 Islands", "LA", 14.1167, 105.8500, ["Don Det", "Si Phan Don"]), ("Pakse", "LA", 15.1202, 105.7990),
    ("Bali", "ID", -8.3405, 115.0920), ("Ubud", "ID", -8.5069, 115.2625), ("Canggu", "ID", -8.6478, 115.1385), ("Uluwatu", "ID", -8.8291, 115.0849),
    ("Seminyak", "ID", -8.6913, 115.1683), ("Nusa Penida", "ID", -8.7278, 115.5444), ("Gili Islands", "ID", -8.3500, 116.0500, ["Gili Trawangan", "Gili T", "Gili Air"]),
    ("Lombok", "ID", -8.6500, 116.3249), ("Komodo", "ID", -8.5500, 119.4833, ["Labuan Bajo"]), ("Yogyakarta", "ID", -7.7956, 110.3695, ["Jogja"]),
    ("Jakarta", "ID", -6.2088, 106.8456), ("Mount Bromo", "ID", -7.9425, 112.9530, ["Bromo"]), ("Ijen", "ID", -8.0583, 114.2422),
    ("Kuala Lumpur", "MY", 3.1390, 101.6869, ["KL"]), ("Penang", "MY", 5.4141, 100.3288, ["George Town"]), ("Langkawi", "MY", 6.3500, 99.8000),
    ("Malacca", "MY", 2.1896, 102.2501, ["Melaka"]), ("Cameron Highlands", "MY", 4.4718, 101.3767), ("Borneo", "MY", 5.9804, 116.0735, ["Kota Kinabalu"]),
    ("Perhentian Islands", "MY", 5.9167, 102.7333, ["Perhentian"]), ("Singapore", "SG", 1.3521, 103.8198),
    ("Manila", "PH", 14.5995, 120.9842), ("El Nido", "PH", 11.1956, 119.4075), ("Coron", "PH", 12.0000, 120.2000), ("Siargao", "PH", 9.8482, 126.0458),
    ("Cebu", "PH", 10.3157, 123.8854), ("Moalboal", "PH", 9.9437, 123.3956), ("Boracay", "PH", 11.9674, 121.9248), ("Bohol", "PH", 9.8500, 124.1435),
    ("Palawan", "PH", 9.8349, 118.7384), ("Puerto Princesa", "PH", 9.7392, 118.7353), ("Siquijor", "PH", 9.1999, 123.5952),
    ("Yangon", "MM", 16.8409, 96.1735), ("Bagan", "MM", 21.1717, 94.8585), ("Inle Lake", "MM", 20.5500, 96.9167),
    ("Dili", "TL", -8.5569, 125.5603),
    # South Asia
    ("Delhi", "IN", 28.6139, 77.2090, ["New Delhi"]), ("Mumbai", "IN", 19.0760, 72.8777), ("Goa", "IN", 15.2993, 74.1240), ("Jaipur", "IN", 26.9124, 75.7873),
    ("Agra", "IN", 27.1767, 78.0081, ["Taj Mahal"]), ("Varanasi", "IN", 25.3176, 82.9739), ("Rishikesh", "IN", 30.0869, 78.2676), ("Udaipur", "IN", 24.5854, 73.7125),
    ("Jodhpur", "IN", 26.2389, 73.0243), ("Jaisalmer", "IN", 26.9157, 70.9083), ("Pushkar", "IN", 26.4897, 74.5511), ("Kerala", "IN", 10.8505, 76.2711, ["Alleppey", "Kochi"]),
    ("Hampi", "IN", 15.3350, 76.4600), ("Darjeeling", "IN", 27.0360, 88.2627), ("McLeod Ganj", "IN", 32.2426, 76.3213, ["Dharamshala"]),
    ("Manali", "IN", 32.2432, 77.1892), ("Leh", "IN", 34.1526, 77.5771, ["Ladakh"]), ("Kolkata", "IN", 22.5726, 88.3639), ("Amritsar", "IN", 31.6340, 74.8723),
    ("Kathmandu", "NP", 27.7172, 85.3240), ("Pokhara", "NP", 28.2096, 83.9856), ("Chitwan", "NP", 27.5291, 84.3542), ("Everest Base Camp", "NP", 28.0026, 86.8528, ["EBC"]),
    ("Annapurna", "NP", 28.5967, 83.8203), ("Colombo", "LK", 6.9271, 79.8612), ("Ella", "LK", 6.8667, 81.0466), ("Kandy", "LK", 7.2906, 80.6337),
    ("Sigiriya", "LK", 7.9570, 80.7603), ("Mirissa", "LK", 5.9483, 80.4716), ("Galle", "LK", 6.0535, 80.2210), ("Arugam Bay", "LK", 6.8400, 81.8360),
    ("Weligama", "LK", 5.9749, 80.4295), ("Male", "MV", 4.1755, 73.5093), ("Maldives", "MV", 3.2028, 73.2207), ("Paro", "BT", 27.4305, 89.4133), ("Thimphu", "BT", 27.4728, 89.6390),
    # East Asia
    ("Tokyo", "JP", 35.6762, 139.6503), ("Kyoto", "JP", 35.0116, 135.7681), ("Osaka", "JP", 34.6937, 135.5023), ("Hiroshima", "JP", 34.3853, 132.4553),
    ("Nara", "JP", 34.6851, 135.8048), ("Hakone", "JP", 35.2324, 139.1069), ("Mount Fuji", "JP", 35.3606, 138.7274, ["Fuji", "Kawaguchiko"]),
    ("Hokkaido", "JP", 43.0642, 141.3469, ["Sapporo"]), ("Okinawa", "JP", 26.2124, 127.6809), ("Nikko", "JP", 36.7199, 139.6982), ("Kanazawa", "JP", 36.5613, 136.6562),
    ("Seoul", "KR", 37.5665, 126.9780), ("Busan", "KR", 35.1796, 129.0756), ("Jeju", "KR", 33.4996, 126.5312), ("Gyeongju", "KR", 35.8562, 129.2247),
    ("Beijing", "CN", 39.9042, 116.4074), ("Shanghai", "CN", 31.2304, 121.4737), ("Chengdu", "CN", 30.5728, 104.0668), ("Xi'an", "CN", 34.3416, 108.9398, ["Xian"]),
    ("Guilin", "CN", 25.2736, 110.2900, ["Yangshuo"]), ("Zhangjiajie", "CN", 29.1170, 110.4792), ("Hong Kong", "HK", 22.3193, 114.1694), ("Macau", "MO", 22.1987, 113.5439),
    ("Taipei", "TW", 25.0330, 121.5654), ("Tainan", "TW", 22.9999, 120.2270), ("Taroko Gorge", "TW", 24.1586, 121.6214, ["Hualien"]), ("Ulaanbaatar", "MN", 47.8864, 106.9057),
    # Oceania
    ("Sydney", "AU", -33.8688, 151.2093), ("Melbourne", "AU", -37.8136, 144.9631), ("Brisbane", "AU", -27.4698, 153.0251), ("Cairns", "AU", -16.9186, 145.7781),
    ("Byron Bay", "AU", -28.6474, 153.6020, ["Byron"]), ("Gold Coast", "AU", -28.0167, 153.4000, ["Surfers Paradise"]), ("Noosa", "AU", -26.3980, 153.0910),
    ("Whitsundays", "AU", -20.2670, 148.7150, ["Whitsunday Islands", "Airlie Beach"]), ("Great Barrier Reef", "AU", -18.2871, 147.6992),
    ("K'gari", "AU", -25.2667, 153.1667, ["Fraser Island"]), ("Uluru", "AU", -25.3444, 131.0369, ["Ayers Rock"]), ("Perth", "AU", -31.9505, 115.8605),
    ("Adelaide", "AU", -34.9285, 138.6007), ("Darwin", "AU", -12.4634, 130.8456), ("Hobart", "AU", -42.8821, 147.3272, ["Tasmania"]),
    ("Great Ocean Road", "AU", -38.6800, 143.3900), ("Margaret River", "AU", -33.9550, 115.0750),
    ("Auckland", "NZ", -36.8485, 174.7633), ("Queenstown", "NZ", -45.0312, 168.6626), ("Wellington", "NZ", -41.2865, 174.7762), ("Rotorua", "NZ", -38.1368, 176.2497),
    ("Wanaka", "NZ", -44.7032, 169.1321), ("Christchurch", "NZ", -43.5321, 172.6362), ("Milford Sound", "NZ", -44.6414, 167.8974), ("Taupo", "NZ", -38.6857, 176.0702),
    ("Abel Tasman", "NZ", -40.9333, 173.0167), ("Franz Josef", "NZ", -43.3880, 170.1830), ("Tongariro", "NZ", -39.2000, 175.5833), ("Raglan", "NZ", -37.8000, 174.8833),
    ("Bay of Islands", "NZ", -35.2167, 174.1667), ("Fiji", "FJ", -17.7134, 178.0650), ("Nadi", "FJ", -17.7765, 177.4356), ("Yasawa Islands", "FJ", -16.9000, 177.4000, ["Yasawa"]),
    # Americas
    ("New York", "US", 40.7128, -74.0060, ["NYC", "New York City"]), ("Los Angeles", "US", 34.0522, -118.2437, ["LA"]), ("San Francisco", "US", 37.7749, -122.4194),
    ("Las Vegas", "US", 36.1699, -115.1398), ("Miami", "US", 25.7617, -80.1918), ("New Orleans", "US", 29.9511, -90.0715), ("Chicago", "US", 41.8781, -87.6298),
    ("Grand Canyon", "US", 36.1069, -112.1129), ("Yosemite", "US", 37.8651, -119.5383), ("Hawaii", "US", 21.3069, -157.8583, ["Honolulu", "Oahu", "Maui"]),
    ("Vancouver", "CA", 49.2827, -123.1207), ("Toronto", "CA", 43.6532, -79.3832), ("Montreal", "CA", 45.5017, -73.5673), ("Banff", "CA", 51.1784, -115.5708, ["Lake Louise"]),
    ("Whistler", "CA", 50.1163, -122.9574), ("Quebec City", "CA", 46.8139, -71.2080),
    ("Mexico City", "MX", 19.4326, -99.1332, ["CDMX"]), ("Oaxaca", "MX", 17.0732, -96.7266), ("Tulum", "MX", 20.2114, -87.4654), ("Cancun", "MX", 21.1619, -86.8515),
    ("Playa del Carmen", "MX", 20.6296, -87.0739), ("Bacalar", "MX", 18.6770, -88.3950), ("Holbox", "MX", 21.5225, -87.3790), ("Merida", "MX", 20.9674, -89.5926, ["Mérida"]),
    ("San Cristobal de las Casas", "MX", 16.7370, -92.6376, ["San Cristobal"]), ("Puerto Escondido", "MX", 15.8720, -97.0767), ("Guadalajara", "MX", 20.6597, -103.3496),
    ("Valladolid", "MX", 20.6896, -88.2011), ("Antigua", "GT", 14.5586, -90.7295), ("Lake Atitlan", "GT", 14.6907, -91.2025, ["Atitlan", "San Pedro La Laguna"]),
    ("Flores", "GT", 16.9300, -89.8920, ["Tikal"]), ("Semuc Champey", "GT", 15.5333, -89.9500), ("Caye Caulker", "BZ", 17.7444, -88.0250), ("San Ignacio", "BZ", 17.1561, -89.0714),
    ("Utila", "HN", 16.0950, -86.9030), ("Roatan", "HN", 16.3300, -86.5300), ("El Tunco", "SV", 13.4930, -89.3830), ("Granada", "NI", 11.9344, -85.9560),
    ("Leon", "NI", 12.4379, -86.8780, ["León"]), ("San Juan del Sur", "NI", 11.2529, -85.8706), ("Ometepe", "NI", 11.5000, -85.5833),
    ("San Jose", "CR", 9.9281, -84.0907), ("La Fortuna", "CR", 10.4678, -84.6427, ["Arenal"]), ("Monteverde", "CR", 10.3000, -84.8167), ("Puerto Viejo", "CR", 9.6560, -82.7530),
    ("Santa Teresa", "CR", 9.6430, -85.1680), ("Manuel Antonio", "CR", 9.3920, -84.1370), ("Panama City", "PA", 8.9824, -79.5199), ("Bocas del Toro", "PA", 9.3403, -82.2420),
    ("San Blas", "PA", 9.5650, -78.8200, ["Guna Yala"]), ("Boquete", "PA", 8.7800, -82.4410), ("Havana", "CU", 23.1136, -82.3666), ("Viñales", "CU", 22.6167, -83.7167, ["Vinales"]),
    ("Trinidad", "CU", 21.8022, -79.9847), ("Cartagena", "CO", 10.3910, -75.4794), ("Medellin", "CO", 6.2442, -75.5812, ["Medellín"]), ("Bogota", "CO", 4.7110, -74.0721, ["Bogotá"]),
    ("Salento", "CO", 4.6380, -75.5700, ["Cocora Valley"]), ("Santa Marta", "CO", 11.2408, -74.1990), ("Minca", "CO", 11.1430, -74.1180), ("Tayrona", "CO", 11.3100, -74.0300),
    ("Palomino", "CO", 11.2470, -73.5640), ("Guatape", "CO", 6.2330, -75.1580, ["Guatapé"]), ("San Gil", "CO", 6.5550, -73.1340), ("Cali", "CO", 3.4516, -76.5320),
    ("Quito", "EC", -0.1807, -78.4678), ("Baños", "EC", -1.3928, -78.4269, ["Banos"]), ("Galapagos", "EC", -0.9538, -90.9656, ["Galápagos"]), ("Montañita", "EC", -1.8300, -80.7500, ["Montanita"]),
    ("Cuenca", "EC", -2.9001, -79.0059), ("Quilotoa", "EC", -0.8600, -78.9000), ("Lima", "PE", -12.0464, -77.0428), ("Cusco", "PE", -13.5320, -71.9675, ["Cuzco"]),
    ("Machu Picchu", "PE", -13.1631, -72.5450), ("Sacred Valley", "PE", -13.3300, -72.0800), ("Rainbow Mountain", "PE", -13.8690, -71.3030, ["Vinicunca"]),
    ("Arequipa", "PE", -16.4090, -71.5375), ("Colca Canyon", "PE", -15.6000, -71.9000), ("Huacachina", "PE", -14.0875, -75.7626), ("Huaraz", "PE", -9.5300, -77.5300),
    ("Puno", "PE", -15.8402, -70.0219), ("Lake Titicaca", "PE", -15.9254, -69.3354, ["Titicaca"]), ("Paracas", "PE", -13.8350, -76.2500), ("Mancora", "PE", -4.1030, -81.0450),
    ("La Paz", "BO", -16.4897, -68.1193), ("Uyuni", "BO", -20.4630, -66.8250, ["Salar de Uyuni", "Salt Flats"]), ("Sucre", "BO", -19.0196, -65.2619), ("Copacabana", "BO", -16.1660, -69.0860),
    ("Rurrenabaque", "BO", -14.4410, -67.5280), ("Santiago", "CL", -33.4489, -70.6693), ("Valparaiso", "CL", -33.0472, -71.6127, ["Valparaíso"]), ("San Pedro de Atacama", "CL", -22.9087, -68.1997, ["Atacama"]),
    ("Torres del Paine", "CL", -50.9423, -73.4068), ("Puerto Natales", "CL", -51.7230, -72.5060), ("Pucon", "CL", -39.2820, -71.9540, ["Pucón"]),
    ("Buenos Aires", "AR", -34.6037, -58.3816), ("Mendoza", "AR", -32.8895, -68.8458), ("Bariloche", "AR", -41.1335, -71.3103), ("El Chalten", "AR", -49.3310, -72.8860, ["El Chaltén"]),
    ("El Calafate", "AR", -50.3379, -72.2648, ["Perito Moreno"]), ("Salta", "AR", -24.7821, -65.4232), ("Iguazu Falls", "AR", -25.6953, -54.4367, ["Iguazu", "Iguaçu", "Foz do Iguaçu"]),
    ("Ushuaia", "AR", -54.8019, -68.3030), ("Rio de Janeiro", "BR", -22.9068, -43.1729, ["Rio"]), ("Sao Paulo", "BR", -23.5505, -46.6333, ["São Paulo"]),
    ("Florianopolis", "BR", -27.5954, -48.5480, ["Florianópolis", "Floripa"]), ("Ilha Grande", "BR", -23.1500, -44.2300), ("Paraty", "BR", -23.2178, -44.7131),
    ("Salvador", "BR", -12.9777, -38.5016), ("Lencois Maranhenses", "BR", -2.4850, -43.1280), ("Montevideo", "UY", -34.9011, -56.1645), ("Punta del Diablo", "UY", -34.0450, -53.5450),
    ("Cabo Polonio", "UY", -34.4030, -53.7830), ("Punta Cana", "DO", 18.5820, -68.4055),
    # Europe
    ("London", "GB", 51.5074, -0.1278), ("Edinburgh", "GB", 55.9533, -3.1883), ("Dublin", "IE", 53.3498, -6.2603), ("Galway", "IE", 53.2707, -9.0568),
    ("Paris", "FR", 48.8566, 2.3522), ("Nice", "FR", 43.7102, 7.2620), ("Lyon", "FR", 45.7640, 4.8357), ("Marseille", "FR", 43.2965, 5.3698), ("Chamonix", "FR", 45.9237, 6.8694),
    ("Barcelona", "ES", 41.3874, 2.1686), ("Madrid", "ES", 40.4168, -3.7038), ("Seville", "ES", 37.3891, -5.9845, ["Sevilla"]), ("Granada", "ES", 37.1773, -3.5986),
    ("Valencia", "ES", 39.4699, -0.3763), ("Ibiza", "ES", 38.9067, 1.4206), ("Mallorca", "ES", 39.6953, 3.0176, ["Majorca"]), ("Tenerife", "ES", 28.2916, -16.6291),
    ("San Sebastian", "ES", 43.3183, -1.9812, ["Donostia"]), ("Malaga", "ES", 36.7213, -4.4214, ["Málaga"]), ("Lisbon", "PT", 38.7223, -9.1393, ["Lisboa"]),
    ("Porto", "PT", 41.1579, -8.6291), ("Lagos", "PT", 37.1028, -8.6730), ("Sintra", "PT", 38.8029, -9.3817), ("Madeira", "PT", 32.7607, -16.9595), ("Azores", "PT", 37.7412, -25.6756),
    ("Rome", "IT", 41.9028, 12.4964, ["Roma"]), ("Florence", "IT", 43.7696, 11.2558, ["Firenze"]), ("Venice", "IT", 45.4408, 12.3155, ["Venezia"]), ("Milan", "IT", 45.4642, 9.1900),
    ("Naples", "IT", 40.8518, 14.2681), ("Amalfi Coast", "IT", 40.6333, 14.6029, ["Amalfi", "Positano"]), ("Cinque Terre", "IT", 44.1461, 9.6439), ("Lake Como", "IT", 46.0160, 9.2572),
    ("Dolomites", "IT", 46.4102, 11.8440), ("Sicily", "IT", 37.6000, 14.0154, ["Palermo"]), ("Sardinia", "IT", 40.1209, 9.0129), ("Bologna", "IT", 44.4949, 11.3426),
    ("Amsterdam", "NL", 52.3676, 4.9041), ("Brussels", "BE", 50.8503, 4.3517), ("Bruges", "BE", 51.2093, 3.2247), ("Berlin", "DE", 52.5200, 13.4050),
    ("Munich", "DE", 48.1351, 11.5820), ("Hamburg", "DE", 53.5511, 9.9937), ("Prague", "CZ", 50.0755, 14.4378), ("Cesky Krumlov", "CZ", 48.8127, 14.3175),
    ("Vienna", "AT", 48.2082, 16.3738), ("Salzburg", "AT", 47.8095, 13.0550), ("Hallstatt", "AT", 47.5622, 13.6493), ("Budapest", "HU", 47.4979, 19.0402),
    ("Krakow", "PL", 50.0647, 19.9450, ["Kraków"]), ("Warsaw", "PL", 52.2297, 21.0122), ("Gdansk", "PL", 54.3520, 18.6466), ("Zurich", "CH", 47.3769, 8.5417),
    ("Interlaken", "CH", 46.6863, 7.8632), ("Lucerne", "CH", 47.0502, 8.3093), ("Zermatt", "CH", 46.0207, 7.7491), ("Geneva", "CH", 46.2044, 6.1432),
    ("Copenhagen", "DK", 55.6761, 12.5683), ("Stockholm", "SE", 59.3293, 18.0686), ("Oslo", "NO", 59.9139, 10.7522), ("Bergen", "NO", 60.3913, 5.3221),
    ("Lofoten", "NO", 68.2090, 13.6170), ("Tromso", "NO", 69.6492, 18.9553, ["Tromsø"]), ("Helsinki", "FI", 60.1699, 24.9384), ("Rovaniemi", "FI", 66.5039, 25.7294, ["Lapland"]),
    ("Reykjavik", "IS", 64.1466, -21.9426, ["Reykjavík"]), ("Tallinn", "EE", 59.4370, 24.7536), ("Riga", "LV", 56.9496, 24.1052), ("Vilnius", "LT", 54.6872, 25.2797),
    ("Ljubljana", "SI", 46.0569, 14.5058), ("Lake Bled", "SI", 46.3683, 14.1146, ["Bled"]), ("Zagreb", "HR", 45.8150, 15.9819), ("Split", "HR", 43.5081, 16.4402),
    ("Dubrovnik", "HR", 42.6507, 18.0944), ("Hvar", "HR", 43.1729, 16.4411), ("Plitvice Lakes", "HR", 44.8654, 15.5820, ["Plitvice"]), ("Zadar", "HR", 44.1194, 15.2314),
    ("Kotor", "ME", 42.4247, 18.7712), ("Budva", "ME", 42.2911, 18.8403), ("Mostar", "BA", 43.3438, 17.8078), ("Sarajevo", "BA", 43.8563, 18.4131),
    ("Belgrade", "RS", 44.7866, 20.4489), ("Tirana", "AL", 41.3275, 19.8187), ("Ksamil", "AL", 39.7660, 20.0000), ("Albanian Riviera", "AL", 40.1300, 19.6400, ["Himare", "Dhermi"]),
    ("Berat", "AL", 40.7058, 19.9522), ("Theth", "AL", 42.3960, 19.7740), ("Ohrid", "MK", 41.1231, 20.8016), ("Skopje", "MK", 41.9981, 21.4254),
    ("Athens", "GR", 37.9838, 23.7275), ("Santorini", "GR", 36.3932, 25.4615), ("Mykonos", "GR", 37.4467, 25.3289), ("Crete", "GR", 35.2401, 24.8093),
    ("Naxos", "GR", 37.1036, 25.3766), ("Ios", "GR", 36.7300, 25.2800), ("Paros", "GR", 37.0853, 25.1500), ("Corfu", "GR", 39.6243, 19.9217), ("Meteora", "GR", 39.7217, 21.6306),
    ("Thessaloniki", "GR", 40.6401, 22.9444), ("Sofia", "BG", 42.6977, 23.3219), ("Bucharest", "RO", 44.4268, 26.1025), ("Brasov", "RO", 45.6427, 25.5887, ["Brașov", "Transylvania"]),
    ("Istanbul", "TR", 41.0082, 28.9784), ("Cappadocia", "TR", 38.6431, 34.8289, ["Goreme", "Göreme"]), ("Antalya", "TR", 36.8969, 30.7133), ("Fethiye", "TR", 36.6216, 29.1164),
    ("Kas", "TR", 36.2018, 29.6377, ["Kaş"]), ("Pamukkale", "TR", 37.9137, 29.1187), ("Tbilisi", "GE", 41.7151, 44.8271), ("Kazbegi", "GE", 42.6570, 44.6410, ["Stepantsminda"]),
    ("Batumi", "GE", 41.6168, 41.6367), ("Yerevan", "AM", 40.1792, 44.4991), ("Malta", "MT", 35.9375, 14.3754, ["Valletta"]), ("Cyprus", "CY", 34.9174, 32.8899),
    # Middle East & Africa
    ("Dubai", "AE", 25.2048, 55.2708), ("Abu Dhabi", "AE", 24.4539, 54.3773), ("Petra", "JO", 30.3285, 35.4444), ("Wadi Rum", "JO", 29.5759, 35.4208), ("Amman", "JO", 31.9454, 35.9284),
    ("Muscat", "OM", 23.5880, 58.3829), ("Cairo", "EG", 30.0444, 31.2357, ["Giza", "Pyramids"]), ("Luxor", "EG", 25.6872, 32.6396), ("Dahab", "EG", 28.4920, 34.5130),
    ("Marrakech", "MA", 31.6295, -7.9811, ["Marrakesh"]), ("Chefchaouen", "MA", 35.1688, -5.2636), ("Fes", "MA", 34.0181, -5.0078, ["Fez"]), ("Essaouira", "MA", 31.5085, -9.7595),
    ("Taghazout", "MA", 30.5444, -9.7090), ("Sahara", "MA", 31.0802, -4.0133, ["Merzouga"]), ("Cape Town", "ZA", -33.9249, 18.4241), ("Johannesburg", "ZA", -26.2041, 28.0473),
    ("Kruger", "ZA", -23.9884, 31.5547, ["Kruger National Park"]), ("Garden Route", "ZA", -33.9600, 22.4600), ("Durban", "ZA", -29.8587, 31.0218),
    ("Victoria Falls", "ZW", -17.9243, 25.8572), ("Okavango Delta", "BW", -19.2833, 22.9000, ["Okavango"]), ("Windhoek", "NA", -22.5609, 17.0658), ("Sossusvlei", "NA", -24.7275, 15.3428),
    ("Nairobi", "KE", -1.2921, 36.8219), ("Masai Mara", "KE", -1.4061, 35.0089, ["Maasai Mara"]), ("Diani", "KE", -4.3180, 39.5800), ("Zanzibar", "TZ", -6.1659, 39.2026, ["Stone Town"]),
    ("Serengeti", "TZ", -2.3333, 34.8333), ("Kilimanjaro", "TZ", -3.0674, 37.3556), ("Arusha", "TZ", -3.3869, 36.6830), ("Kigali", "RW", -1.9441, 30.0619),
    ("Jinja", "UG", 0.4244, 33.2042), ("Madagascar", "MG", -18.8792, 47.5079, ["Antananarivo"]), ("Mauritius", "MU", -20.3484, 57.5522), ("Lake Malawi", "MW", -12.0000, 34.5000),
    ("Accra", "GH", 5.6037, -0.1870), ("Dakar", "SN", 14.7167, -17.4677),
]


def iso_flag(cc):
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in cc.upper())


def slug(name):
    out = []
    for ch in name.lower():
        if ch.isalnum():
            out.append(ch)
        elif ch in " -'":
            out.append("-")
    s = "".join(out)
    while "--" in s:
        s = s.replace("--", "-")
    return s.strip("-")


def main(src):
    data = json.load(open(src, encoding="utf-8"))
    countries = []
    for c in data:
        cc = c["cca2"]
        if cc in ("AQ", "BV", "HM", "UM", "TF", "IO", "GS"):
            continue
        name = c["name"]["common"]
        currencies = [{"code": k, "name": v.get("name", k), "symbol": v.get("symbol", "")} for k, v in (c.get("currencies") or {}).items()]
        idd = c.get("idd") or {}
        suffixes = idd.get("suffixes") or [""]
        calling = (idd.get("root", "") + (suffixes[0] if len(suffixes) == 1 else "")).strip()
        region = c.get("region", "")
        plugs = PLUGS.get(cc) or (EUROPE_DEFAULT_PLUG if region == "Europe" else "")
        emergency = EMERGENCY.get(cc) or ("112" if cc in EU_112 else "")
        lat, lng = (c.get("latlng") or [0, 0])[:2]
        countries.append({
            "code": cc,
            "alpha3": c.get("cca3", ""),
            "name": name,
            "officialName": c["name"].get("official", name),
            "flag": c.get("flag") or iso_flag(cc),
            "capital": (c.get("capital") or [""])[0],
            "region": region,
            "subregion": c.get("subregion", ""),
            "latitude": lat,
            "longitude": lng,
            "currencies": currencies,
            "languages": list((c.get("languages") or {}).values()),
            "callingCode": calling,
            "plugs": plugs,
            "drivingSide": "left" if cc in LEFT_DRIVING else "right",
            "emergency": emergency,
            "dailyCostUSD": DAILY_USD.get(cc),
            "tipping": TIPPING.get(cc, ""),
            "bestTime": BEST_TIME.get(cc, ""),
            "travelAdviceSlug": GOVUK_SLUG.get(cc, slug(name)),
            "aliases": [a for a in (c.get("altSpellings") or []) if len(a) > 3 and a.isascii() and a != name][:4],
            "borders": c.get("borders") or [],
            "landlocked": bool(c.get("landlocked")),
            "area": c.get("area") or 0,
        })
    countries.sort(key=lambda x: x["name"])
    codes = {c["code"] for c in countries}

    places = []
    for p in PLACES:
        name, cc, lat, lon = p[:4]
        aliases = p[4] if len(p) > 4 else []
        assert cc in codes, (name, cc)
        places.append({"name": name, "countryCode": cc, "latitude": lat, "longitude": lon, "aliases": aliases})

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "countries.json"), "w", encoding="utf-8") as f:
        json.dump(countries, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "places.json"), "w", encoding="utf-8") as f:
        json.dump(places, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(countries)} countries, {len(places)} places")


if __name__ == "__main__":
    main(sys.argv[1])
