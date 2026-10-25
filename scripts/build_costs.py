#!/usr/bin/env python3
"""Builds the South-East Asia cost & rules datasets bundled in the app.

    python3 scripts/build_costs.py

All money is in GBP. Figures are typical 2025-26 backpacker prices compiled
from the sources listed in docs/data-sources.md (checked Oct 2026). They are
planning estimates - the app lets you override every one of them.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources")
CHECKED = "Oct 2026"


def daily(food, transport, activities, necessities, other):
    return {"food": food, "localTransport": transport, "activities": activities,
            "necessities": necessities, "other": other}


# ---------------------------------------------------------------- countries
COUNTRIES = [
    {
        "code": "TH",
        "daily": {"budget": daily(9, 4, 4, 3, 5), "flashpacker": daily(16, 7, 8, 4, 10)},
        "accommodation": {"dorm": 9, "private": 25},
        "visa": {
            "freeDays": 30, "cost": 0, "longerStayCost": 44,
            "summary": "UK passports: visa-free for 30 days (cut from 60 on 15 Sep 2026). Tourism only.",
            "how": "No visa needed for up to 30 days. Fill in the free TDAC arrival card online within 72 hours before you land.",
            "longerStayNote": "Staying longer: extend once by 30 days at an immigration office (about 1,900 THB) or apply for a tourist e-visa before you go.",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Complete the Thailand Digital Arrival Card (TDAC) at tdac.immigration.go.th within 72 hours before arrival - it's free; ignore paid lookalike sites.",
                "Passport must be valid for 6 months from arrival with a blank page.",
                "You may be asked for proof of onward travel and funds (officially 20,000 THB per person) - have a booking screenshot ready.",
                "Visa-free stay is 30 days from 15 Sep 2026. Overstaying costs 500 THB per day and can lead to a ban.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Vapes and e-cigarettes are illegal to bring in, own or use. Tourists have been fined and detained - leave them at home.",
                "Never criticise or joke about the King or royal family (lèse-majesté) - including online. Prison sentences are long.",
                "Cannabis is restricted again: recreational use isn't allowed and buying needs a prescription. Don't take any across borders.",
                "Drug offences carry very heavy sentences - including the death penalty for trafficking.",
                "Alcohol isn't sold 2pm-5pm or after midnight in shops, and not at all on some Buddhist holidays and election days.",
                "Buddha images/statues need an export licence. Don't use Buddha images as decoration or tattoos in disrespectful ways.",
                "Stepping on money is disrespectful (it shows the King). Don't touch people's heads; don't point feet at people or shrines.",
                "Littering and smoking on many beaches is banned with big fines (e.g. Patong, Koh Samui).",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the LEFT. You need a 1949 International Driving Permit (Post Office, £5.50) PLUS your UK licence with motorcycle (A/A1) entitlement to ride legally.",
                "Without the right licence, police fine you (typically 500-1,000 THB) and your travel insurance usually won't pay out after a crash.",
                "Helmets are compulsory for rider and passenger. Police checkpoints in Phuket, Pai, Chiang Mai and the islands are common.",
                "Never hand over your passport as a rental deposit - pay a cash deposit instead. Photograph the bike before you ride.",
            ]},
            {"title": "Health & safety", "symbol": "cross.case.fill", "points": [
                "Dengue is common - use DEET repellent, especially in the rainy season.",
                "Rabies: avoid touching dogs, cats and monkeys. If bitten or scratched, get to a hospital the same day.",
                "Don't drink tap water. Ice in restaurants is generally made from purified water.",
                "Full Moon Party: watch your drink, avoid buckets from strangers, don't swim drunk.",
            ]},
            {"title": "Scams & etiquette", "symbol": "hand.raised.fill", "points": [
                "'The Grand Palace is closed today' is a scam leading to gem shops. Use Grab or Bolt instead of tuk-tuk 'tours'.",
                "Jet-ski 'damage' scams in Phuket/Pattaya - photograph everything before renting, or don't rent.",
                "Cover shoulders and knees for temples; remove shoes. Dress codes are enforced at the Grand Palace.",
                "Stand for the royal anthem at cinemas and at 8am/6pm in public places.",
            ]},
        ],
        "spendNote": "Backpackers typically spend about £30-40 a day including a dorm. The islands (Koh Tao, Phi Phi, Samui) cost more; the north (Chiang Mai, Pai) costs less.",
    },
    {
        "code": "VN",
        "daily": {"budget": daily(6, 3, 3, 2, 4), "flashpacker": daily(12, 6, 6, 3, 8)},
        "accommodation": {"dorm": 6, "private": 17},
        "visa": {
            "freeDays": 45, "cost": 0, "longerStayCost": 20,
            "summary": "UK passports: visa-free for 45 days (runs to March 2028).",
            "how": "No visa needed for up to 45 days. For longer, get the 90-day e-visa at evisa.gov.vn ($25 single / $50 multiple entry) - avoid agency sites charging more.",
            "longerStayNote": "Over 45 days: apply for the 90-day e-visa ($25) before arrival.",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "45 days visa-free for UK passports, counting the day you arrive. Plan your exit date carefully.",
                "Staying longer? The official e-visa site is evisa.gov.vn - processing takes 3-5 working days.",
                "Passport must be valid for 6 months with 2 blank pages.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "E-cigarettes and vapes are banned (from 2025) - fines of several million dong and confiscation on the spot.",
                "Drug penalties are severe, up to the death penalty. Police have been raiding bars in Ho Chi Minh City and drug-testing guests.",
                "Flying a drone needs a permit - drones are often confiscated at the airport or near military areas.",
                "Don't photograph military sites, police or border areas.",
                "Political criticism of the government (including online) can get you in serious trouble.",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Vietnam only accepts a 1968-convention International Driving Permit - the 1949 one used in Thailand is NOT valid. Buy the 1968 IDP at the Post Office (£5.50).",
                "The IDP must cover motorbikes (category A/A1), which means your UK licence needs motorcycle entitlement. Otherwise you're riding unlicensed.",
                "Riding unlicensed: fines of 2-4 million VND, bike impounded, and insurance usually void. On the Ha Giang Loop most backpackers use an 'easy rider' driver for this reason.",
                "Helmets are compulsory. Traffic is chaotic - walk slowly and predictably when crossing.",
            ]},
            {"title": "Health & safety", "symbol": "cross.case.fill", "points": [
                "Don't drink tap water. Street food is generally safe at busy stalls.",
                "Sapa/Ha Giang get cold Nov-Feb - bring layers. The north floods in the rainy season.",
                "Watch bags on motorbike-passing streets in Saigon - snatch thefts happen.",
            ]},
            {"title": "Scams & etiquette", "symbol": "hand.raised.fill", "points": [
                "Agree taxi and cyclo prices first, or use Grab. Check the number of zeros on dong notes (10,000 vs 100,000).",
                "Hoi An tailors: agree price, fabric and fitting dates in writing.",
                "Dress modestly in pagodas; remove shoes where others do.",
            ]},
        ],
        "spendNote": "One of the cheapest countries - about £20-28 a day on a budget. Big extras are the Ha Giang Loop, Ha Long/Lan Ha cruises and the long north-south trip.",
    },
    {
        "code": "KH",
        "daily": {"budget": daily(6, 3, 3, 2, 4), "flashpacker": daily(11, 6, 6, 3, 7)},
        "accommodation": {"dorm": 5, "private": 15},
        "visa": {
            "freeDays": 0, "cost": 28, "longerStayCost": 0,
            "summary": "UK passports need a 30-day tourist visa: e-visa about $36 or visa on arrival $30 cash.",
            "how": "Apply for the e-visa at evisa.gov.kh ($30 + processing) or get a visa on arrival with US$ cash and a passport photo. Also fill in the free e-Arrival card at arrival.gov.kh within 7 days before flying in.",
            "longerStayNote": "Extend inside Cambodia through an agent (prices vary).",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Visa needed: e-visa (evisa.gov.kh, about $36) or visa on arrival ($30, bring US dollars cash and a photo).",
                "Fill in the free Cambodia e-Arrival card (arrival.gov.kh) - mandatory for air arrivals.",
                "At land borders (e.g. Poipet, Bavet), ignore 'visa helpers' charging extra and only pay the official fee.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Drug penalties are heavy. 'Happy' pizzas and shakes can contain unknown substances.",
                "Don't take photos of children in schools or orphanages; avoid 'orphanage tourism' entirely.",
                "Dress modestly at Angkor - shoulders and knees covered, or you'll be refused entry to some temples.",
                "Only buy Angkor passes at the official ticket office or angkorenterprise.gov.kh.",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the right. A 1949 IDP plus motorcycle entitlement on your licence is needed to ride legally.",
                "Most backpackers use tuk-tuks or PassApp/Grab - cheap and avoids insurance problems.",
            ]},
            {"title": "Health & safety", "symbol": "cross.case.fill", "points": [
                "Landmines remain in rural areas, especially near the Thai border - stick to marked paths.",
                "Bag snatching from passing motorbikes happens in Phnom Penh - keep your phone away from the road side.",
            ]},
            {"title": "Money", "symbol": "dollarsign.circle.fill", "points": [
                "US dollars are used everywhere alongside riel - carry clean, untorn small notes.",
                "ATMs give dollars and charge around $5 per withdrawal.",
            ]},
        ],
        "spendNote": "About £18-25 a day on a budget. The Angkor pass ($37 for 1 day, $62 for 3 days) is the big extra.",
    },
    {
        "code": "LA",
        "daily": {"budget": daily(6, 3, 3, 2, 3), "flashpacker": daily(10, 5, 6, 3, 6)},
        "accommodation": {"dorm": 6, "private": 15},
        "visa": {
            "freeDays": 0, "cost": 31, "longerStayCost": 0,
            "summary": "UK passports need a 30-day tourist visa: visa on arrival about US$40 cash, or an e-visa (check your entry point accepts it).",
            "how": "Visa on arrival at Vientiane, Luang Prabang and Pakse airports and the main Thai-Lao Friendship Bridges. Bring US$ cash and a passport photo.",
            "longerStayNote": "Extend in Vientiane or Luang Prabang immigration offices.",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Visa on arrival costs about $40 for UK citizens - bring clean US dollar notes and a passport photo.",
                "If using the e-visa, check your border crossing accepts it (not all do).",
                "Passport needs 6 months' validity and a blank page.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Relationships/sex between foreigners and Lao nationals outside marriage are illegal - fines are enforced.",
                "Drug offences carry very heavy penalties. Police in Vang Vieng run spot checks.",
                "Unexploded ordnance (UXO) is still a danger in rural areas - never leave marked paths.",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the right. A 1949 IDP with motorcycle entitlement is needed; insurance is usually void without it.",
                "Rental shops in Vang Vieng and Thakhek (Kong Lor loop) may charge for any scratch - photograph the bike first.",
            ]},
            {"title": "Getting around", "symbol": "tram.fill", "points": [
                "The Laos-China railway is the quickest way between Vientiane, Vang Vieng and Luang Prabang - buy tickets via the LCR Ticket app or at stations; they sell out.",
                "The 2-day slow boat (Huay Xai-Pakbeng-Luang Prabang) is a classic - prices have risen with fuel costs.",
            ]},
        ],
        "spendNote": "The cheapest country on most routes - around £15-22 a day. Note that ATM fees are high.",
    },
    {
        "code": "ID",
        "daily": {"budget": daily(7, 4, 4, 2, 5), "flashpacker": daily(15, 8, 8, 3, 10)},
        "accommodation": {"dorm": 9, "private": 24},
        "visa": {
            "freeDays": 0, "cost": 24, "longerStayCost": 24,
            "summary": "UK passports: e-VOA or visa on arrival, IDR 500,000 (about £24) for 30 days, extendable once by 30 days.",
            "how": "Apply for the e-VOA at evisa.imigrasi.go.id before you fly and complete the All Indonesia arrival card (customs + health) within 72 hours of arrival. Pay the Bali tourist levy (IDR 150,000) via the Love Bali app.",
            "longerStayNote": "Extend the VOA once for another 30 days (another IDR 500,000) before it expires.",
        },
        "entryFees": [{"name": "Bali tourist levy", "cost": 7, "note": "IDR 150,000, paid online (Love Bali)"}],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Get the e-VOA (IDR 500,000) at evisa.imigrasi.go.id - many lookalike sites charge 2-3x more.",
                "Complete the All Indonesia arrival card online within 72 hours of arrival.",
                "Bali: pay the IDR 150,000 tourist levy online and keep the QR code.",
                "Passport needs 6 months' validity and is checked strictly. Have an onward ticket.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Drug trafficking carries the death penalty, and possession means long prison terms. This includes 'magic mushroom' shakes in Gili/Bali.",
                "The new criminal code (from Jan 2026) criminalises sex outside marriage and cohabitation - prosecution needs a complaint from a family member, and officials say tourists won't be targeted.",
                "Bali code of conduct: respect temples, don't climb sacred trees or sit on shrines, and dress modestly at temples (sarong).",
                "Disrespecting Islam or Hinduism, or posing nude at sacred sites, has led to deportations.",
                "Overstaying your visa costs IDR 1,000,000 per day.",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the LEFT. You need a 1949 IDP with motorcycle entitlement - Bali police run regular checkpoints targeting tourists.",
                "Bali authorities have pushed to stop rental of scooters to tourists without a valid licence.",
                "Riding unlicensed usually voids travel insurance - Bali scooter crashes are the #1 insurance claim.",
                "The Gili Islands have no motor vehicles - bikes and horse carts only.",
            ]},
            {"title": "Health & safety", "symbol": "cross.case.fill", "points": [
                "Bali belly: avoid tap water and ice from unknown sources.",
                "Methanol poisoning from fake spirits (arak) has killed tourists - stick to beer or sealed bottles.",
                "Rabies is present in Bali - avoid dogs and monkeys (Monkey Forest monkeys bite).",
                "Check volcano alerts before Batur, Rinjani, Ijen or Bromo treks.",
            ]},
        ],
        "spendNote": "Bali averages £25-35 a day on a budget, but Canggu/Seminyak can be much more. Java, Lombok and Flores are cheaper.",
    },
    {
        "code": "MY",
        "daily": {"budget": daily(8, 4, 4, 3, 4), "flashpacker": daily(14, 7, 7, 4, 8)},
        "accommodation": {"dorm": 9, "private": 24},
        "visa": {
            "freeDays": 90, "cost": 0, "longerStayCost": 0,
            "summary": "UK passports: visa-free for 90 days.",
            "how": "No visa needed. Complete the free Malaysia Digital Arrival Card (MDAC) within 3 days before arrival.",
            "longerStayNote": "",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Complete the free MDAC on the official immigration site within 3 days before arrival - avoid paid agents.",
                "Sabah and Sarawak (Borneo) have their own immigration control - you'll be stamped again.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Drug trafficking carries the death penalty, and possession means prison.",
                "Vaping rules are strict in some states. Don't vape in public places.",
                "Dress modestly at mosques - robes are usually provided.",
                "Public displays of affection can offend, especially on the east coast (Kelantan, Terengganu).",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the LEFT. You need a 1949 IDP plus your UK licence.",
                "Langkawi and Penang are easy to explore by scooter, but check that your licence covers motorbikes.",
            ]},
            {"title": "Good to know", "symbol": "info.circle.fill", "points": [
                "Grab works everywhere and is cheap.",
                "Alcohol is pricey except on duty-free Langkawi.",
            ]},
        ],
        "spendNote": "About £25-35 a day on a budget. Food is cheap and excellent (Penang!), but alcohol is expensive.",
    },
    {
        "code": "SG",
        "daily": {"budget": daily(15, 6, 10, 4, 8), "flashpacker": daily(25, 10, 15, 5, 15)},
        "accommodation": {"dorm": 25, "private": 70},
        "visa": {
            "freeDays": 30, "cost": 0, "longerStayCost": 0,
            "summary": "UK passports: visa-free for up to 30 days.",
            "how": "Submit the free SG Arrival Card (ICA website or MyICA app) within 3 days before arrival.",
            "longerStayNote": "",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Submit the free SG Arrival Card within 3 days before arrival.",
                "Declare cigarettes - there's no duty-free allowance on them and fines are big.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "E-cigarettes and vapes are illegal to bring in, own or use - heavy fines, and enforcement increased in 2025.",
                "Chewing gum can't be imported or sold.",
                "Littering, jaywalking, eating or drinking on the MRT, and not flushing public toilets are all fined.",
                "Drug offences carry the death penalty; you can be tested on arrival and prosecuted for drugs taken abroad.",
                "Smoking only in marked areas.",
            ]},
            {"title": "Good to know", "symbol": "info.circle.fill", "points": [
                "Hawker centres (Maxwell, Lau Pa Sat, Chinatown) give £3-5 meals.",
                "Use a contactless bank card directly on the MRT and buses.",
            ]},
        ],
        "spendNote": "The most expensive stop in SEA - plan around £50-70 a day even in a dorm, so most backpackers stay 2-3 nights.",
    },
    {
        "code": "PH",
        "daily": {"budget": daily(8, 5, 5, 2, 5), "flashpacker": daily(14, 9, 8, 3, 9)},
        "accommodation": {"dorm": 10, "private": 26},
        "visa": {
            "freeDays": 30, "cost": 0, "longerStayCost": 40,
            "summary": "UK passports: visa-free for 30 days with an onward/return ticket.",
            "how": "Register on eTravel (etravel.gov.ph, free) within 72 hours before arrival - airlines may not board you without the QR code.",
            "longerStayNote": "Extend at Bureau of Immigration offices inside the Philippines (about 3,000-4,000 PHP for +29 days).",
        },
        "entryFees": [],
        "rules": [
            {"title": "Before you arrive", "symbol": "doc.text.fill", "points": [
                "Register on eTravel (free) within 72 hours of arrival and keep the QR code.",
                "Have proof of onward travel - it's checked at check-in and immigration.",
                "Many island hops need domestic flights - book early in high season (Dec-May).",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Drug laws are extremely strict.",
                "Vaping is banned in many public places and some cities have stricter bans.",
                "Taking sand, shells or coral from beaches (e.g. Boracay, El Nido) is illegal.",
                "Environmental fees are compulsory in El Nido (₱400), Coron and other protected areas.",
            ]},
            {"title": "Scooters & driving", "symbol": "scooter", "points": [
                "Drive on the right. A UK licence is accepted for 90 days, but insurers usually want motorcycle entitlement.",
                "Siargao, Bohol and Siquijor are popular by scooter - roads can be unlit at night.",
            ]},
            {"title": "Health & safety", "symbol": "cross.case.fill", "points": [
                "Typhoon season is roughly Jun-Nov - ferries are cancelled at short notice.",
                "Check FCDO advice: some parts of Mindanao are 'advise against all travel'.",
            ]},
        ],
        "spendNote": "About £25-35 a day on a budget, plus island-hopping tours (around £20-35 each) and domestic flights.",
    },
    {
        "code": "MM",
        "daily": {"budget": daily(6, 4, 4, 2, 3), "flashpacker": daily(10, 7, 7, 3, 6)},
        "accommodation": {"dorm": 8, "private": 20},
        "visa": {
            "freeDays": 0, "cost": 39, "longerStayCost": 0,
            "summary": "UK passports need an e-visa (about US$50, 28 days). No visa on arrival.",
            "how": "Apply online at the official e-visa portal before travel.",
            "longerStayNote": "Tourist stays are capped at 28 days.",
        },
        "entryFees": [],
        "rules": [
            {"title": "Check before you go", "symbol": "exclamationmark.triangle.fill", "points": [
                "The UK FCDO advises against all travel to parts of Myanmar and all but essential travel to others. Your insurance may be void if you go against FCDO advice.",
                "The situation changes quickly - check gov.uk/foreign-travel-advice/myanmar before booking.",
            ]},
            {"title": "Laws you could break by accident", "symbol": "exclamationmark.shield.fill", "points": [
                "Don't photograph military or police, or protests. Political discussion can be dangerous for locals.",
                "Drones are banned without permits.",
            ]},
        ],
        "spendNote": "Cheap, but cash-based (bring clean US dollars). Insurance cover is the main issue.",
    },
]

# ------------------------------------------------------- per-place hostels
PLACES = [
    # name, country, dorm, private, aliases
    ("Bangkok", "TH", 10, 28), ("Chiang Mai", "TH", 7, 20), ("Pai", "TH", 6, 16), ("Chiang Rai", "TH", 6, 16),
    ("Koh Phangan", "TH", 10, 25), ("Koh Tao", "TH", 11, 28), ("Koh Samui", "TH", 12, 30), ("Phuket", "TH", 10, 28),
    ("Krabi", "TH", 9, 25, ["Ao Nang"]), ("Koh Lanta", "TH", 9, 24), ("Koh Phi Phi", "TH", 15, 40), ("Railay", "TH", 15, 40),
    ("Khao Sok", "TH", 8, 22), ("Kanchanaburi", "TH", 6, 16), ("Ayutthaya", "TH", 7, 18), ("Koh Chang", "TH", 8, 22),
    ("Sukhothai", "TH", 6, 15), ("Koh Lipe", "TH", 13, 35),
    ("Hanoi", "VN", 6, 18), ("Ha Giang", "VN", 5, 14), ("Sapa", "VN", 6, 16), ("Ninh Binh", "VN", 6, 16),
    ("Ha Long Bay", "VN", 6, 16, ["Cat Ba"]), ("Phong Nha", "VN", 5, 14), ("Hue", "VN", 5, 14), ("Hoi An", "VN", 6, 18),
    ("Da Nang", "VN", 6, 18), ("Da Lat", "VN", 5, 14), ("Nha Trang", "VN", 6, 16), ("Mui Ne", "VN", 6, 16),
    ("Ho Chi Minh City", "VN", 6, 18), ("Mekong Delta", "VN", 5, 14), ("Phu Quoc", "VN", 8, 22),
    ("Phnom Penh", "KH", 5, 16), ("Siem Reap", "KH", 4, 14), ("Kampot", "KH", 5, 14), ("Koh Rong", "KH", 7, 20),
    ("Battambang", "KH", 4, 12), ("Sihanoukville", "KH", 6, 16),
    ("Luang Prabang", "LA", 6, 16), ("Vang Vieng", "LA", 5, 14), ("Vientiane", "LA", 6, 16), ("Nong Khiaw", "LA", 5, 12),
    ("4000 Islands", "LA", 4, 10), ("Pakse", "LA", 5, 12),
    ("Bali", "ID", 9, 24), ("Ubud", "ID", 8, 22), ("Canggu", "ID", 12, 32), ("Uluwatu", "ID", 11, 30), ("Seminyak", "ID", 12, 32),
    ("Nusa Penida", "ID", 9, 24), ("Gili Islands", "ID", 9, 25), ("Lombok", "ID", 7, 20), ("Komodo", "ID", 8, 22),
    ("Yogyakarta", "ID", 5, 15), ("Jakarta", "ID", 7, 20), ("Mount Bromo", "ID", 7, 18), ("Ijen", "ID", 7, 18),
    ("Kuala Lumpur", "MY", 8, 22), ("Penang", "MY", 8, 20), ("Langkawi", "MY", 9, 24), ("Malacca", "MY", 7, 20),
    ("Cameron Highlands", "MY", 7, 20), ("Perhentian Islands", "MY", 10, 26), ("Borneo", "MY", 8, 22),
    ("Singapore", "SG", 25, 70),
    ("Manila", "PH", 10, 26), ("El Nido", "PH", 12, 30), ("Coron", "PH", 11, 28), ("Siargao", "PH", 12, 30), ("Cebu", "PH", 9, 24),
    ("Moalboal", "PH", 9, 22), ("Boracay", "PH", 13, 35), ("Bohol", "PH", 9, 22), ("Palawan", "PH", 11, 28),
    ("Puerto Princesa", "PH", 9, 24), ("Siquijor", "PH", 9, 22),
    ("Yangon", "MM", 8, 20), ("Bagan", "MM", 8, 20), ("Inle Lake", "MM", 7, 18),
]

# ------------------------------------------------------------------ tours
def tour(id, name, place, country, budget, flash, duration, keywords, notes="", kind="tour"):
    return {"id": id, "name": name, "place": place, "country": country, "budget": budget, "flashpacker": flash,
            "duration": duration, "keywords": keywords, "notes": notes, "kind": kind}

TOURS = [
    # Vietnam
    tour("ha-giang-easy-rider", "Ha Giang Loop - easy rider (3-4 days)", "Ha Giang", "VN", 160, 240, "3-4 days",
         ["ha giang", "loop", "easy rider"], "Includes driver, homestays, meals and permit. The most popular way to do it legally."),
    tour("ha-giang-self-drive", "Ha Giang Loop - self-drive (4 days)", "Ha Giang", "VN", 110, 170, "4 days",
         ["ha giang", "self drive", "self-drive"], "Bike rental, fuel and homestays. Needs a 1968 IDP with motorbike category."),
    tour("lan-ha-2d1n", "Ha Long / Lan Ha Bay cruise (2 days, 1 night)", "Ha Long Bay", "VN", 115, 170, "2 days",
         ["ha long", "halong", "lan ha", "cruise", "overnight cruise"], "Budget boats from about $145. Lan Ha is quieter and slightly cheaper than classic Ha Long."),
    tour("lan-ha-day", "Ha Long / Lan Ha Bay day cruise", "Ha Long Bay", "VN", 35, 70, "1 day",
         ["ha long day", "halong day", "lan ha day", "day cruise"], "From Hanoi, including transfer and lunch."),
    tour("sapa-trek", "Sapa 2-day trek with homestay", "Sapa", "VN", 35, 60, "2 days", ["sapa", "trek", "homestay"]),
    tour("fansipan", "Fansipan cable car", "Sapa", "VN", 25, 30, "half day", ["fansipan", "cable car"], kind="ticket"),
    tour("tam-coc-boat", "Tam Coc / Trang An boat ride", "Ninh Binh", "VN", 8, 15, "2-3 hours",
         ["tam coc", "trang an", "boat", "ninh binh"], kind="ticket"),
    tour("ninh-binh-day", "Ninh Binh day tour from Hanoi", "Ninh Binh", "VN", 30, 50, "1 day", ["ninh binh day", "hoa lu", "mua cave"]),
    tour("phong-nha-paradise", "Paradise Cave + Dark Cave (Phong Nha)", "Phong Nha", "VN", 25, 40, "1 day",
         ["phong nha", "paradise cave", "dark cave"]),
    tour("hue-imperial", "Hue Imperial City ticket", "Hue", "VN", 6, 6, "half day", ["imperial city", "citadel", "hue"], kind="ticket"),
    tour("hai-van-pass", "Hai Van Pass motorbike tour (Hue - Hoi An)", "Hoi An", "VN", 35, 55, "1 day",
         ["hai van", "top gear", "pass"], "Easy rider plus luggage transfer - a great way to travel between Hue and Hoi An."),
    tour("hoi-an-cooking", "Hoi An cooking class", "Hoi An", "VN", 20, 35, "half day", ["cooking class", "hoi an cooking"]),
    tour("hoi-an-lantern", "Hoi An lantern boat", "Hoi An", "VN", 4, 8, "30 min", ["lantern", "lantern boat"], kind="ticket"),
    tour("my-son", "My Son Sanctuary tour", "Hoi An", "VN", 12, 25, "half day", ["my son", "sanctuary"]),
    tour("ba-na", "Ba Na Hills & Golden Bridge", "Da Nang", "VN", 32, 45, "1 day", ["ba na", "golden bridge"]),
    tour("dalat-canyoning", "Da Lat canyoning", "Da Lat", "VN", 25, 40, "1 day", ["canyoning", "dalat canyoning"]),
    tour("mui-ne-jeep", "Mui Ne sand dunes sunrise jeep", "Mui Ne", "VN", 10, 20, "4 hours", ["sand dunes", "mui ne", "jeep"]),
    tour("cu-chi", "Cu Chi Tunnels half-day tour", "Ho Chi Minh City", "VN", 15, 35, "half day", ["cu chi", "tunnels"]),
    tour("mekong-day", "Mekong Delta day tour", "Mekong Delta", "VN", 18, 40, "1 day", ["mekong", "floating market"]),
    tour("hanoi-food", "Hanoi street food tour", "Hanoi", "VN", 15, 30, "3 hours", ["street food", "food tour", "hanoi food"]),
    tour("water-puppet", "Water puppet show", "Hanoi", "VN", 5, 8, "1 hour", ["water puppet", "puppet"], kind="ticket"),
    tour("phu-quoc-islands", "Phu Quoc island hopping & snorkel", "Phu Quoc", "VN", 20, 35, "1 day", ["phu quoc", "island hopping"]),
    tour("nha-trang-islands", "Nha Trang island tour", "Nha Trang", "VN", 12, 25, "1 day", ["nha trang", "island tour"]),
    # Thailand
    tour("khao-sok-day", "Khao Sok - Cheow Lan Lake day tour", "Khao Sok", "TH", 45, 80, "1 day",
         ["khao sok", "cheow lan", "lake", "boat tour"], "Longtail boat, cave, kayak and lunch. Booking locally in Khao Sok is cheaper than from Phuket."),
    tour("khao-sok-overnight", "Khao Sok - 2 day floating raft house", "Khao Sok", "TH", 115, 200, "2 days",
         ["khao sok overnight", "raft house", "floating bungalow", "floating raft"], "Night on the lake, safaris, meals included."),
    tour("elephant-nature-park", "Elephant Nature Park (ethical sanctuary)", "Chiang Mai", "TH", 60, 75, "1 day",
         ["elephant", "sanctuary", "elephant nature park"], "Choose no-riding, no-bathing sanctuaries."),
    tour("doi-inthanon", "Doi Inthanon day trip", "Chiang Mai", "TH", 25, 50, "1 day", ["doi inthanon", "inthanon"]),
    tour("cm-cooking", "Chiang Mai cooking class", "Chiang Mai", "TH", 25, 35, "half day", ["cooking class", "thai cooking"]),
    tour("sticky-waterfall", "Sticky Waterfall trip", "Chiang Mai", "TH", 8, 20, "half day", ["sticky waterfall", "bua tong"]),
    tour("muay-thai-fight", "Muay Thai fight night", "Bangkok", "TH", 30, 50, "evening", ["muay thai fight", "rajadamnern", "lumpinee"], kind="ticket"),
    tour("muay-thai-class", "Muay Thai class", "Chiang Mai", "TH", 10, 18, "2 hours", ["muay thai class", "muay thai training"]),
    tour("white-temple", "Chiang Rai White & Blue Temple day trip", "Chiang Rai", "TH", 25, 45, "1 day", ["white temple", "blue temple", "chiang rai day"]),
    tour("pai-canyon", "Pai Canyon & scooter day", "Pai", "TH", 6, 10, "1 day", ["pai canyon", "pai scooter"]),
    tour("pai-rafting", "Pai bamboo rafting / tubing", "Pai", "TH", 10, 25, "half day", ["rafting", "bamboo raft", "tubing pai"]),
    tour("padi-koh-tao", "PADI Open Water course (Koh Tao)", "Koh Tao", "TH", 255, 300, "3-4 days",
         ["padi", "open water", "dive course", "scuba course"], "About 11,000-12,000 THB, often with a few nights' free dorm included."),
    tour("fun-dive-koh-tao", "Fun dives (2 dives)", "Koh Tao", "TH", 45, 60, "half day", ["fun dive", "2 dives", "diving"]),
    tour("koh-tao-snorkel", "Koh Tao around-island snorkel trip", "Koh Tao", "TH", 18, 30, "1 day", ["snorkel", "koh nang yuan", "around the island"]),
    tour("ang-thong", "Ang Thong Marine Park tour", "Koh Samui", "TH", 40, 65, "1 day", ["ang thong", "marine park"]),
    tour("full-moon", "Full Moon Party", "Koh Phangan", "TH", 25, 50, "night", ["full moon", "half moon", "jungle party"],
         "Entry fee is about 200 THB plus buckets - budget for the night out.", kind="ticket"),
    tour("phi-phi-tour", "Phi Phi islands day tour (Maya Bay)", "Phuket", "TH", 40, 65, "1 day", ["phi phi", "maya bay"],
         "Maya Bay national park fee extra (about 400 THB)."),
    tour("phi-phi-sunset", "Phi Phi sunset & plankton boat", "Koh Phi Phi", "TH", 25, 35, "half day", ["sunset cruise", "plankton", "phi phi boat"]),
    tour("krabi-4-islands", "Krabi 4 islands longtail tour", "Krabi", "TH", 18, 35, "1 day", ["4 islands", "four islands", "krabi islands"]),
    tour("railay-climbing", "Railay rock climbing (half day)", "Railay", "TH", 30, 45, "half day", ["climbing", "rock climbing"]),
    tour("james-bond", "Phang Nga Bay / James Bond Island", "Phuket", "TH", 35, 65, "1 day", ["james bond", "phang nga"]),
    tour("similan", "Similan Islands snorkel day trip", "Phuket", "TH", 90, 130, "1 day", ["similan"]),
    tour("lanta-4-islands", "Koh Lanta 4 islands snorkel tour", "Koh Lanta", "TH", 25, 40, "1 day", ["lanta", "emerald cave", "koh rok"]),
    tour("erawan", "Erawan Falls trip", "Kanchanaburi", "TH", 12, 30, "1 day", ["erawan"]),
    tour("death-railway", "Death Railway & River Kwai tour", "Kanchanaburi", "TH", 20, 40, "1 day", ["death railway", "river kwai"]),
    tour("ayutthaya-day", "Ayutthaya temples day trip", "Ayutthaya", "TH", 15, 35, "1 day", ["ayutthaya"]),
    tour("grand-palace", "Grand Palace & Wat Phra Kaew ticket", "Bangkok", "TH", 12, 12, "half day", ["grand palace", "wat phra kaew"], kind="ticket"),
    tour("bkk-food", "Bangkok street food tour", "Bangkok", "TH", 25, 45, "3 hours", ["food tour", "street food", "chinatown"]),
    tour("floating-market", "Damnoen Saduak & Maeklong railway market", "Bangkok", "TH", 20, 40, "half day", ["floating market", "railway market", "maeklong"]),
    tour("thai-massage", "Thai massage (1 hour)", "Chiang Mai", "TH", 7, 12, "1 hour", ["massage"], kind="ticket"),
    # Cambodia
    tour("angkor-1", "Angkor pass - 1 day", "Siem Reap", "KH", 29, 29, "1 day", ["angkor 1 day", "angkor wat ticket", "angkor pass"], "$37 at the official office only.", kind="ticket"),
    tour("angkor-3", "Angkor pass - 3 days", "Siem Reap", "KH", 48, 48, "3 days", ["angkor 3 day", "3 day pass"], "$62, valid for 3 days within a set window.", kind="ticket"),
    tour("angkor-tuktuk", "Angkor tuk-tuk driver (per day)", "Siem Reap", "KH", 13, 18, "1 day", ["tuk tuk", "angkor tuk", "angkor sunrise"]),
    tour("angkor-small-group", "Angkor sunrise small-group tour", "Siem Reap", "KH", 25, 45, "1 day", ["angkor tour", "sunrise tour", "angkor wat sunrise"]),
    tour("phare", "Phare, The Cambodian Circus", "Siem Reap", "KH", 15, 30, "evening", ["phare", "circus"], kind="ticket"),
    tour("killing-fields", "Killing Fields & S-21 (Tuol Sleng)", "Phnom Penh", "KH", 15, 30, "half day", ["killing fields", "s21", "tuol sleng"]),
    tour("kampot-kep", "Kampot pepper farm & Kep tour", "Kampot", "KH", 15, 30, "1 day", ["pepper farm", "kep", "kampot tour"]),
    tour("koh-rong-plankton", "Koh Rong snorkel & bioluminescent plankton trip", "Koh Rong", "KH", 15, 25, "half day", ["plankton", "bioluminescent", "koh rong snorkel"]),
    tour("bamboo-train", "Battambang bamboo train & bat cave", "Battambang", "KH", 12, 20, "half day", ["bamboo train", "bat cave"]),
    # Laos
    tour("kuang-si", "Kuang Si Falls", "Luang Prabang", "LA", 8, 20, "half day", ["kuang si", "kuang xi", "waterfall"]),
    tour("gibbon", "The Gibbon Experience (3 days)", "Luang Prabang", "LA", 280, 320, "3 days", ["gibbon experience", "ziplines", "treehouse"],
         "Starts from Huay Xai - book weeks ahead."),
    tour("lp-cooking", "Luang Prabang cooking class", "Luang Prabang", "LA", 25, 35, "half day", ["cooking class", "lao cooking"]),
    tour("vv-tubing", "Vang Vieng tubing", "Vang Vieng", "LA", 6, 10, "half day", ["tubing"]),
    tour("vv-balloon", "Vang Vieng hot air balloon", "Vang Vieng", "LA", 75, 90, "1 hour", ["hot air balloon", "balloon"]),
    tour("vv-blue-lagoon", "Blue Lagoon, caves & kayaking tour", "Vang Vieng", "LA", 18, 30, "1 day", ["blue lagoon", "kayak", "kayaking"]),
    tour("nong-khiaw-trek", "Nong Khiaw 100 Waterfalls trek", "Nong Khiaw", "LA", 20, 35, "1 day", ["100 waterfalls", "nong khiaw trek"]),
    tour("kong-lor", "Thakhek loop & Kong Lor cave", "Vientiane", "LA", 45, 80, "3-4 days", ["kong lor", "thakhek", "the loop laos"]),
    tour("4000-kayak", "4000 Islands kayak & waterfalls", "4000 Islands", "LA", 18, 28, "1 day", ["don det", "4000 islands", "kayak"]),
    tour("bolaven", "Bolaven Plateau loop", "Pakse", "LA", 35, 70, "2-3 days", ["bolaven"]),
    # Indonesia
    tour("batur", "Mount Batur sunrise trek", "Ubud", "ID", 30, 45, "early morning", ["batur", "sunrise trek", "volcano sunrise"]),
    tour("nusa-penida-tour", "Nusa Penida day tour (west side)", "Nusa Penida", "ID", 35, 55, "1 day", ["nusa penida", "kelingking"]),
    tour("manta-snorkel", "Manta ray snorkel (Nusa Penida)", "Nusa Penida", "ID", 25, 40, "half day", ["manta"]),
    tour("monkey-forest", "Ubud Monkey Forest", "Ubud", "ID", 5, 5, "2 hours", ["monkey forest"], kind="ticket"),
    tour("ubud-swing", "Ubud jungle swing & rice terraces", "Ubud", "ID", 20, 35, "half day", ["bali swing", "jungle swing", "tegallalang", "rice terraces"]),
    tour("canggu-surf", "Surf lesson (Canggu)", "Canggu", "ID", 20, 30, "2 hours", ["surf lesson", "surfing", "surf"]),
    tour("uluwatu-kecak", "Uluwatu Temple & Kecak fire dance", "Uluwatu", "ID", 9, 12, "evening", ["kecak", "uluwatu temple"], kind="ticket"),
    tour("gili-snorkel", "Gili 3-islands snorkel trip (turtles)", "Gili Islands", "ID", 8, 15, "half day", ["gili snorkel", "turtles", "snorkel"]),
    tour("padi-gili", "PADI Open Water course (Gili T)", "Gili Islands", "ID", 300, 340, "3-4 days", ["padi", "open water", "dive course"]),
    tour("rinjani", "Mount Rinjani 2D1N crater rim trek", "Lombok", "ID", 150, 230, "2 days", ["rinjani"]),
    tour("komodo-boat", "Komodo National Park 2-3 day boat trip", "Komodo", "ID", 160, 260, "2-3 days", ["komodo", "liveaboard", "padar", "pink beach"],
         "Liveaboard from Labuan Bajo with Padar, Pink Beach and Komodo dragons. Park fees can add more."),
    tour("komodo-day", "Komodo day trip (speedboat)", "Komodo", "ID", 70, 110, "1 day", ["komodo day"]),
    tour("borobudur", "Borobudur sunrise", "Yogyakarta", "ID", 40, 60, "early morning", ["borobudur"]),
    tour("prambanan", "Prambanan temple ticket", "Yogyakarta", "ID", 16, 16, "half day", ["prambanan"], kind="ticket"),
    tour("ijen", "Ijen blue fire trek", "Ijen", "ID", 35, 60, "night", ["ijen", "blue fire"]),
    tour("bromo", "Mount Bromo sunrise jeep", "Mount Bromo", "ID", 25, 45, "early morning", ["bromo"]),
    # Malaysia
    tour("petronas", "Petronas Towers skybridge", "Kuala Lumpur", "MY", 25, 25, "1 hour", ["petronas", "skybridge"], kind="ticket"),
    tour("batu", "Batu Caves", "Kuala Lumpur", "MY", 0, 0, "half day", ["batu caves"], kind="ticket"),
    tour("penang-food", "Penang street food tour", "Penang", "MY", 25, 40, "3 hours", ["penang food", "george town food"]),
    tour("cameron-tour", "Cameron Highlands tea & Mossy Forest tour", "Cameron Highlands", "MY", 15, 30, "half day", ["mossy forest", "tea plantation"]),
    tour("langkawi-cable", "Langkawi SkyCab cable car", "Langkawi", "MY", 15, 25, "half day", ["skycab", "cable car", "sky bridge"], kind="ticket"),
    tour("langkawi-islands", "Langkawi island hopping", "Langkawi", "MY", 8, 18, "half day", ["langkawi island"]),
    tour("perhentian-snorkel", "Perhentian snorkel trip", "Perhentian Islands", "MY", 10, 18, "half day", ["perhentian"]),
    tour("kinabalu", "Mount Kinabalu climb (2 days)", "Borneo", "MY", 260, 360, "2 days", ["kinabalu"], "Permits are limited - book months ahead."),
    tour("kinabatangan", "Kinabatangan River wildlife (3 days)", "Borneo", "MY", 120, 200, "3 days", ["kinabatangan", "orangutan", "sepilok"]),
    # Singapore
    tour("gardens-domes", "Gardens by the Bay domes", "Singapore", "SG", 27, 27, "half day", ["gardens by the bay", "cloud forest"], kind="ticket"),
    tour("universal-sg", "Universal Studios Singapore", "Singapore", "SG", 50, 50, "1 day", ["universal studios", "sentosa"], kind="ticket"),
    # Philippines
    tour("el-nido-a", "El Nido island tour A (lagoons)", "El Nido", "PH", 25, 35, "1 day", ["el nido tour", "tour a", "big lagoon", "small lagoon"],
         "Plus ₱400 environmental fee and ₱200 lagoon fee."),
    tour("el-nido-c", "El Nido island tour C (beaches)", "El Nido", "PH", 25, 35, "1 day", ["tour c", "hidden beach", "secret beach"]),
    tour("coron-ultimate", "Coron ultimate island tour", "Coron", "PH", 30, 45, "1 day", ["coron", "kayangan", "twin lagoon"]),
    tour("el-nido-coron-expedition", "El Nido to Coron 3-day boat expedition", "El Nido", "PH", 380, 450, "3 days", ["tao expedition", "el nido to coron", "expedition"]),
    tour("kawasan", "Kawasan Falls canyoneering", "Moalboal", "PH", 25, 40, "half day", ["kawasan", "canyoneering"]),
    tour("moalboal-sardines", "Moalboal sardine run & turtle snorkel", "Moalboal", "PH", 5, 15, "2 hours", ["sardine", "moalboal snorkel"]),
    tour("siargao-islands", "Siargao island hopping (Naked, Daku, Guyam)", "Siargao", "PH", 15, 25, "1 day", ["siargao", "naked island", "daku"]),
    tour("siargao-surf", "Siargao surf lesson", "Siargao", "PH", 12, 20, "2 hours", ["surf lesson", "cloud 9"]),
    tour("bohol-countryside", "Bohol countryside tour (Chocolate Hills, tarsiers)", "Bohol", "PH", 25, 40, "1 day", ["chocolate hills", "tarsier", "bohol"]),
    tour("underground-river", "Puerto Princesa Underground River", "Puerto Princesa", "PH", 35, 50, "1 day", ["underground river"]),
    # Myanmar
    tour("bagan-ebike", "Bagan e-bike temple day", "Bagan", "MM", 8, 15, "1 day", ["e-bike", "bagan temples"]),
    tour("inle-boat", "Inle Lake boat day", "Inle Lake", "MM", 15, 25, "1 day", ["inle", "leg rowers"]),
    tour("kalaw-trek", "Kalaw to Inle trek (3 days)", "Inle Lake", "MM", 45, 70, "3 days", ["kalaw", "trek"]),
]

# Fallback price bands by activity type (GBP, budget style, Thailand = 1.0).
BANDS = [
    (["padi", "open water", "dive course", "scuba course"], "Dive course", 260),
    (["fun dive", "diving", "dive"], "Fun dives", 45),
    (["liveaboard", "expedition", "2 day", "3 day", "overnight", "2d1n"], "Multi-day trip", 120),
    (["cruise"], "Boat cruise", 60),
    (["cooking"], "Cooking class", 22),
    (["trek", "hike", "hiking", "volcano", "sunrise"], "Trek", 30),
    (["snorkel"], "Snorkel trip", 20),
    (["island hopping", "islands", "island tour"], "Island hopping", 25),
    (["canyon", "canyoning", "canyoneering"], "Canyoning", 30),
    (["zipline", "zip line", "flight of the gibbon"], "Zipline", 45),
    (["kayak", "rafting", "tubing", "paddle"], "Water activity", 18),
    (["surf"], "Surf lesson", 20),
    (["climb", "climbing"], "Climbing", 30),
    (["massage", "spa"], "Massage", 8),
    (["class", "workshop", "lesson"], "Class", 20),
    (["show", "circus", "fight", "party", "concert"], "Show / event", 20),
    (["ticket", "entry", "museum", "temple", "palace", "park"], "Entry ticket", 8),
    (["scooter", "motorbike", "bike rental"], "Scooter rental", 5),
    (["day trip", "tour", "safari", "boat"], "Day tour", 28),
]
COUNTRY_FACTOR = {"TH": 1.0, "VN": 0.8, "KH": 0.75, "LA": 0.8, "ID": 0.9, "MY": 1.0, "SG": 1.8, "PH": 0.95, "MM": 0.85}

# ------------------------------------------------------- transport routes
def leg(a, b, mode, budget, flash, hours, tip=""):
    return {"from": a, "to": b, "mode": mode, "budget": budget, "flashpacker": flash, "hours": hours, "tip": tip}

ROUTES = [
    # Thailand
    leg("Bangkok", "Chiang Mai", "sleeperTrain", 24, 60, 12, "Train 9 or 13 overnight - 2nd class A/C berth about 900-1,200 THB. Book 2-4 weeks ahead; flights are about £30-50."),
    leg("Chiang Mai", "Pai", "minibus", 5, 8, 3.5, "762 bends - take travel sickness tablets. About 200-250 THB."),
    leg("Chiang Mai", "Chiang Rai", "bus", 6, 10, 3.5, "Green Bus, about 250 THB."),
    leg("Pai", "Chiang Rai", "minibus", 10, 15, 6, "Usually via Chiang Mai."),
    leg("Bangkok", "Ayutthaya", "train", 1, 4, 1.5, "3rd class train costs 15-20 THB - one of the cheapest rides in Asia."),
    leg("Bangkok", "Kanchanaburi", "train", 2, 6, 3, "Thonburi station, about 100 THB."),
    leg("Bangkok", "Sukhothai", "bus", 10, 15, 7),
    leg("Sukhothai", "Chiang Mai", "bus", 8, 12, 5),
    leg("Ayutthaya", "Chiang Mai", "sleeperTrain", 22, 55, 11, "Same night trains as from Bangkok."),
    leg("Bangkok", "Koh Tao", "ferry", 25, 45, 10, "Joint bus/train + Lomprayah ferry ticket via Chumphon."),
    leg("Bangkok", "Koh Phangan", "ferry", 28, 50, 12, "Night train or bus to Surat Thani, then ferry."),
    leg("Bangkok", "Koh Samui", "flight", 85, 140, 1.2, "Bangkok Airways has a monopoly on Samui - the bus + ferry is much cheaper (about £25)."),
    leg("Koh Tao", "Koh Phangan", "ferry", 14, 20, 1.5, "Lomprayah/Seatran, about 600 THB."),
    leg("Koh Phangan", "Koh Samui", "ferry", 7, 12, 0.5, "Haad Rin Queen or Seatran."),
    leg("Koh Samui", "Krabi", "ferry", 22, 30, 6, "Joint ferry and bus via Donsak."),
    leg("Koh Phangan", "Krabi", "ferry", 24, 32, 7),
    leg("Koh Tao", "Krabi", "ferry", 28, 38, 9),
    leg("Koh Phangan", "Khao Sok", "ferry", 18, 25, 5, "Ferry to Surat Thani, then minibus."),
    leg("Koh Samui", "Khao Sok", "ferry", 18, 25, 4.5),
    leg("Khao Sok", "Krabi", "minibus", 9, 14, 3),
    leg("Khao Sok", "Phuket", "minibus", 9, 14, 3),
    leg("Bangkok", "Khao Sok", "bus", 20, 30, 11, "Night bus or train to Surat Thani, then minibus."),
    leg("Krabi", "Koh Phi Phi", "ferry", 9, 14, 1.5),
    leg("Phuket", "Koh Phi Phi", "ferry", 10, 16, 2),
    leg("Koh Phi Phi", "Koh Lanta", "ferry", 10, 14, 1.5),
    leg("Krabi", "Koh Lanta", "minibus", 7, 10, 2.5),
    leg("Krabi", "Railay", "ferry", 3, 5, 0.3, "Longtail from Ao Nang, about 100-150 THB."),
    leg("Phuket", "Krabi", "minibus", 8, 12, 3),
    leg("Bangkok", "Phuket", "flight", 30, 60, 1.4, "AirAsia/Thai Lion - the 12-hour bus is about £20."),
    leg("Bangkok", "Krabi", "flight", 30, 60, 1.3),
    leg("Chiang Mai", "Krabi", "flight", 40, 70, 2),
    leg("Chiang Mai", "Phuket", "flight", 40, 70, 2),
    leg("Chiang Mai", "Koh Samui", "flight", 90, 150, 2),
    leg("Bangkok", "Koh Chang", "bus", 12, 18, 6, "Bus + car ferry from Ekkamai."),
    leg("Koh Lanta", "Koh Lipe", "ferry", 40, 55, 4),
    # Thailand <-> Laos/Cambodia/Malaysia
    leg("Chiang Rai", "Luang Prabang", "slowBoat", 40, 60, 48, "Bus to Chiang Khong, cross to Huay Xai, then the 2-day slow boat with a night in Pakbeng (about 600,000-750,000 kip + guesthouse)."),
    leg("Chiang Mai", "Luang Prabang", "slowBoat", 45, 70, 52, "Minibus to the border + 2-day slow boat via Pakbeng. Flights are about £70-110."),
    leg("Pai", "Luang Prabang", "slowBoat", 48, 72, 54, "Via Chiang Mai/Chiang Khong and the 2-day slow boat."),
    leg("Bangkok", "Vientiane", "sleeperTrain", 25, 45, 12, "Night train to Nong Khai, then shuttle train over the Friendship Bridge."),
    leg("Bangkok", "Siem Reap", "bus", 20, 30, 9, "Direct bus via Poipet (Nattakan/Giant Ibis). Get your visa beforehand to dodge border scams."),
    leg("Bangkok", "Phnom Penh", "flight", 50, 90, 1.2),
    leg("Koh Lipe", "Langkawi", "ferry", 30, 40, 1.5),
    leg("Krabi", "Penang", "minibus", 25, 35, 10, "Via Hat Yai, or fly."),
    leg("Bangkok", "Kuala Lumpur", "flight", 35, 70, 2.2),
    leg("Bangkok", "Hanoi", "flight", 50, 90, 2),
    leg("Bangkok", "Bali", "flight", 90, 150, 4.5),
    leg("Bangkok", "Manila", "flight", 80, 140, 3.5),
    # Laos
    leg("Luang Prabang", "Vang Vieng", "train", 14, 20, 1, "Laos-China railway, 2nd class about 200,000-300,000 kip. Book on the LCR app - it sells out."),
    leg("Vang Vieng", "Vientiane", "train", 10, 14, 1),
    leg("Luang Prabang", "Vientiane", "train", 20, 30, 2),
    leg("Luang Prabang", "Nong Khiaw", "minibus", 7, 10, 3.5),
    leg("Vientiane", "Pakse", "sleeperBus", 15, 22, 10, "VIP sleeper bus with double beds - you may share with a stranger."),
    leg("Pakse", "4000 Islands", "minibus", 6, 9, 3, "Includes the boat to Don Det."),
    leg("Vientiane", "4000 Islands", "sleeperBus", 22, 30, 14),
    leg("4000 Islands", "Siem Reap", "bus", 22, 30, 10, "Via the Nong Nok Khiene border - only pay the official visa fee."),
    leg("4000 Islands", "Phnom Penh", "bus", 20, 28, 10),
    leg("Vientiane", "Hanoi", "flight", 70, 110, 1.2, "The 24-hour bus is about £30 but rough."),
    leg("Luang Prabang", "Hanoi", "flight", 80, 120, 1.2, "The overland bus takes about 24 hours."),
    # Vietnam
    leg("Hanoi", "Ha Giang", "sleeperBus", 10, 15, 6, "Sleeper or limousine bus, about 250,000-400,000 VND."),
    leg("Hanoi", "Sapa", "sleeperBus", 11, 18, 6, "Or the night train to Lao Cai + transfer."),
    leg("Sapa", "Ha Giang", "minibus", 12, 18, 7),
    leg("Hanoi", "Ninh Binh", "bus", 5, 9, 2),
    leg("Hanoi", "Ha Long Bay", "bus", 8, 14, 3, "Usually included with cruise packages."),
    leg("Ha Long Bay", "Ninh Binh", "bus", 10, 15, 3.5),
    leg("Ha Giang", "Ninh Binh", "sleeperBus", 14, 20, 8),
    leg("Ninh Binh", "Phong Nha", "sleeperBus", 14, 20, 8),
    leg("Hanoi", "Phong Nha", "sleeperBus", 15, 22, 9),
    leg("Ninh Binh", "Hue", "sleeperTrain", 25, 40, 11, "Or the cheaper sleeper bus (about £14)."),
    leg("Hanoi", "Hue", "sleeperTrain", 28, 45, 12, "SE trains overnight. Soft seats from about 730,000 VND; berths cost more."),
    leg("Phong Nha", "Hue", "bus", 8, 12, 4),
    leg("Hue", "Hoi An", "bus", 6, 10, 4, "Or take the Hai Van Pass motorbike tour instead (see Tours)."),
    leg("Hue", "Da Nang", "train", 5, 8, 2.5, "One of the world's most scenic train rides."),
    leg("Da Nang", "Hoi An", "bus", 1, 8, 1, "Local bus or a Grab (about £8)."),
    leg("Hoi An", "Da Lat", "sleeperBus", 15, 22, 14),
    leg("Hoi An", "Nha Trang", "sleeperBus", 13, 20, 11),
    leg("Hoi An", "Ho Chi Minh City", "flight", 35, 60, 1.5, "Fly from Da Nang."),
    leg("Nha Trang", "Da Lat", "bus", 6, 10, 4),
    leg("Da Lat", "Mui Ne", "bus", 7, 10, 4),
    leg("Da Lat", "Ho Chi Minh City", "sleeperBus", 9, 14, 7),
    leg("Mui Ne", "Ho Chi Minh City", "bus", 7, 10, 5),
    leg("Ho Chi Minh City", "Mekong Delta", "bus", 5, 9, 3.5),
    leg("Ho Chi Minh City", "Phu Quoc", "flight", 30, 55, 1),
    leg("Hanoi", "Ho Chi Minh City", "flight", 40, 70, 2.1, "The train takes 33+ hours (about £40)."),
    leg("Hanoi", "Da Nang", "flight", 35, 60, 1.3),
    leg("Hanoi", "Hoi An", "flight", 35, 60, 1.3, "Fly to Da Nang + 45 min transfer."),
    leg("Ho Chi Minh City", "Phnom Penh", "bus", 13, 20, 7, "Giant Ibis / Kumho - buy the Cambodian visa beforehand."),
    leg("Mekong Delta", "Phnom Penh", "ferry", 25, 35, 6, "Boat up the Mekong from Chau Doc."),
    leg("Ho Chi Minh City", "Siem Reap", "bus", 22, 30, 13),
    leg("Ho Chi Minh City", "Bangkok", "flight", 45, 80, 1.5),
    leg("Hanoi", "Siem Reap", "flight", 80, 120, 1.8),
    # Cambodia
    leg("Phnom Penh", "Siem Reap", "bus", 9, 14, 6, "Giant Ibis or Larryta, about $12-15."),
    leg("Phnom Penh", "Kampot", "minibus", 7, 10, 3),
    leg("Kampot", "Koh Rong", "ferry", 18, 25, 4, "Bus to Sihanoukville + speed ferry."),
    leg("Siem Reap", "Koh Rong", "bus", 25, 35, 11, "Night bus to Sihanoukville, then ferry."),
    leg("Phnom Penh", "Koh Rong", "ferry", 18, 25, 5),
    leg("Siem Reap", "Battambang", "bus", 6, 10, 3.5, "Or a boat in the wet season (about £20, 6-8 hours)."),
    leg("Battambang", "Phnom Penh", "bus", 8, 12, 5),
    leg("Siem Reap", "Bangkok", "bus", 20, 30, 9),
    leg("Koh Rong", "Phu Quoc", "ferry", 25, 35, 6, "Via Ha Tien."),
    leg("Phnom Penh", "Kuala Lumpur", "flight", 45, 80, 2),
    leg("Phnom Penh", "Bali", "flight", 110, 170, 4.5),
    leg("Siem Reap", "Bali", "flight", 110, 170, 5),
    leg("Koh Rong", "Bali", "flight", 120, 180, 6, "Via Phnom Penh or Kuala Lumpur."),
    # Indonesia
    leg("Bali", "Gili Islands", "ferry", 20, 30, 2.5, "Fast boat from Padang Bai or Serangan, about IDR 350,000-500,000 one way."),
    leg("Canggu", "Gili Islands", "ferry", 22, 32, 3.5),
    leg("Ubud", "Gili Islands", "ferry", 22, 32, 3.5),
    leg("Gili Islands", "Lombok", "ferry", 3, 10, 0.5, "Public boat to Bangsal."),
    leg("Bali", "Nusa Penida", "ferry", 9, 14, 0.7, "Fast boat from Sanur."),
    leg("Ubud", "Nusa Penida", "ferry", 11, 16, 1.5),
    leg("Canggu", "Nusa Penida", "ferry", 11, 16, 1.5),
    leg("Bali", "Ubud", "car", 10, 15, 1.2, "Grab or Gojek car, or a scooter."),
    leg("Ubud", "Canggu", "car", 9, 12, 1.2),
    leg("Canggu", "Uluwatu", "car", 9, 12, 1),
    leg("Ubud", "Uluwatu", "car", 12, 16, 1.5),
    leg("Bali", "Komodo", "flight", 55, 90, 1.2, "Fly into Labuan Bajo."),
    leg("Lombok", "Komodo", "flight", 55, 90, 1.2),
    leg("Bali", "Yogyakarta", "flight", 45, 75, 1.3),
    leg("Yogyakarta", "Mount Bromo", "train", 12, 25, 9, "Train to Probolinggo/Malang + jeep, or a tour package."),
    leg("Mount Bromo", "Ijen", "minibus", 15, 25, 6),
    leg("Ijen", "Bali", "ferry", 5, 15, 3, "Ferry Ketapang to Gilimanuk + bus."),
    leg("Jakarta", "Yogyakarta", "train", 15, 30, 8),
    leg("Bali", "Kuala Lumpur", "flight", 60, 100, 3),
    leg("Bali", "Singapore", "flight", 60, 110, 2.6),
    # Malaysia / Singapore
    leg("Kuala Lumpur", "Penang", "train", 15, 22, 4, "ETS electric train from KL Sentral to Butterworth + ferry."),
    leg("Kuala Lumpur", "Cameron Highlands", "bus", 8, 12, 4),
    leg("Cameron Highlands", "Penang", "bus", 9, 13, 5),
    leg("Cameron Highlands", "Perhentian Islands", "minibus", 30, 40, 7, "Minibus + boat from Kuala Besut."),
    leg("Penang", "Langkawi", "ferry", 15, 20, 3),
    leg("Kuala Lumpur", "Malacca", "bus", 4, 7, 2),
    leg("Malacca", "Singapore", "bus", 8, 15, 4),
    leg("Kuala Lumpur", "Singapore", "bus", 10, 20, 5, "Or fly (about £30)."),
    leg("Kuala Lumpur", "Langkawi", "flight", 25, 45, 1),
    leg("Kuala Lumpur", "Borneo", "flight", 40, 70, 2.5, "Kota Kinabalu."),
    leg("Singapore", "Bali", "flight", 60, 110, 2.6),
    leg("Singapore", "Manila", "flight", 70, 120, 3.5),
    # Philippines
    leg("Manila", "El Nido", "flight", 70, 120, 1.5, "Direct flights or via Puerto Princesa (+ 5-6 hours by van)."),
    leg("Manila", "Puerto Princesa", "flight", 40, 70, 1.3),
    leg("Puerto Princesa", "El Nido", "minibus", 9, 14, 5.5),
    leg("El Nido", "Coron", "ferry", 35, 45, 4, "Montenegro or Atienza fast ferry."),
    leg("Coron", "Manila", "flight", 50, 85, 1),
    leg("Manila", "Cebu", "flight", 35, 60, 1.3),
    leg("Cebu", "Moalboal", "bus", 3, 30, 3.5, "Ceres bus from the South Bus Terminal (cheap) or a private car."),
    leg("Cebu", "Bohol", "ferry", 12, 20, 2),
    leg("Cebu", "Siargao", "flight", 40, 70, 1),
    leg("Moalboal", "Siquijor", "ferry", 15, 22, 5),
    leg("Bohol", "Siquijor", "ferry", 15, 22, 2),
    leg("Manila", "Siargao", "flight", 55, 90, 2),
    leg("Manila", "Boracay", "flight", 45, 80, 1.1, "Fly to Caticlan + boat."),
    leg("Cebu", "Boracay", "flight", 45, 80, 1),
    # Myanmar
    leg("Yangon", "Bagan", "sleeperBus", 15, 22, 10),
    leg("Bagan", "Inle Lake", "bus", 12, 18, 8),
    leg("Inle Lake", "Yangon", "sleeperBus", 15, 22, 11),
]

# Fallback rates (GBP) when a leg isn't in the table.
FALLBACK = {
    "busPerKm": {"TH": 0.025, "VN": 0.02, "KH": 0.022, "LA": 0.025, "ID": 0.03, "MY": 0.028, "SG": 0.04, "PH": 0.03, "MM": 0.025, "default": 0.03},
    "busMinimum": 3,
    "flightBase": 35, "flightPerKm": 0.035,
    "ferryDefault": 15,
    "flashpackerMultiplier": 1.5,
}

# ------------------------------------------------------------ fixed costs
def fixed(key, name, category, budget, flash, per, note="", included=True, group="Before you go"):
    return {"key": key, "name": name, "category": category, "budget": budget, "flashpacker": flash,
            "per": per, "note": note, "defaultIncluded": included, "group": group}

FIXED = [
    fixed("flights", "Return flights London ⇄ Bangkok", "flights", 550, 750, "trip",
          "Typical economy return fare; usually £450-750, cheapest in Feb-Mar and Oct, most expensive in December.", group="Flights"),
    fixed("insurance", "Backpacker travel insurance", "insurance", 45, 75, "month",
          "Per month. Needs cover for scooters (with a licence), diving and adventure activities, and medical evacuation.", group="Insurance"),
    fixed("esim", "eSIM data (per country, 30 days)", "other", 10, 15, "country",
          "e.g. Airalo or Holafly, about 10GB for 30 days. Or buy a local SIM at the airport for less.", group="Phone & data"),
    fixed("idp-1949", "International Driving Permit (1949)", "visas", 5.5, 5.5, "trip",
          "From the Post Office. Covers Thailand, Cambodia, Laos, Malaysia, Indonesia and the Philippines.", group="Documents"),
    fixed("idp-1968", "International Driving Permit (1968) - Vietnam", "visas", 5.5, 5.5, "trip",
          "Vietnam only accepts the 1968 IDP. Only needed if you'll ride in Vietnam.", group="Documents"),
    fixed("travel-clinic", "Travel clinic consultation", "insurance", 25, 40, "trip", "Pharmacy travel clinics (Boots, Superdrug, independent).", group="Health"),
    fixed("vax-nhs", "Hep A, Typhoid, Tetanus/Diphtheria/Polio", "insurance", 0, 0, "trip", "Free on the NHS - book through your GP practice nurse 6-8 weeks before you go.", group="Health"),
    fixed("vax-rabies", "Rabies vaccine (3 doses)", "insurance", 210, 210, "trip", "About £60-75 per dose. Strongly recommended for long trips and scooter riders.", group="Health"),
    fixed("vax-je", "Japanese encephalitis (2 doses)", "insurance", 200, 200, "trip", "About £100 per dose. Recommended for long stays in rural SEA.", group="Health"),
    fixed("vax-hepb", "Hepatitis B (3 doses)", "insurance", 150, 150, "trip", "Optional - recommended for tattoos, medical work or volunteering.", included=False, group="Health"),
    fixed("malaria", "Malaria tablets", "insurance", 30, 60, "trip", "Usually not needed for the main SEA backpacker routes - ask the travel clinic.", included=False, group="Health"),
    fixed("backpack", "Backpack (40-50L)", "gear", 90, 150, "trip", "e.g. Osprey Farpoint/Fairview 40.", group="Gear"),
    fixed("daypack", "Daypack / packable bag", "gear", 20, 40, "trip", group="Gear"),
    fixed("powerbank", "Power bank (20,000mAh)", "gear", 25, 45, "trip", "Must go in hand luggage.", group="Gear"),
    fixed("adapter", "Universal travel adapter", "gear", 12, 25, "trip", group="Gear"),
    fixed("small-gear", "Packing cubes, padlock, towel, dry bag, headtorch", "gear", 50, 80, "trip", group="Gear"),
    fixed("first-aid", "First-aid kit & meds (Imodium, rehydration, antihistamines)", "gear", 25, 40, "trip", group="Gear"),
    fixed("toiletries", "Toiletries & suncream to start", "gear", 25, 40, "trip", "Suncream is expensive in SEA - bring some from home.", group="Gear"),
    fixed("bank-card", "Fee-free travel card (Wise/Revolut/Monzo/Starling)", "other", 0, 0, "trip", "Avoids 3% foreign fees. Expect local ATM fees of about £5 per withdrawal in Thailand and Cambodia.", group="Money"),
    fixed("atm-fees", "ATM fees on the road", "other", 8, 8, "month", "Thai ATMs charge 220 THB per withdrawal - withdraw larger amounts less often.", group="Money"),
    fixed("emergency", "Emergency fund", "other", 300, 500, "trip", "For missed flights, a lost phone or medical excess. Keep it untouched if possible.", included=False, group="Money"),
]


def main():
    os.makedirs(OUT, exist_ok=True)

    def dump(name, obj):
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))

    for c in COUNTRIES:
        c["checked"] = CHECKED
    dump("sea_countries.json", COUNTRIES)
    places = []
    for p in PLACES:
        places.append({"place": p[0], "country": p[1], "dorm": p[2], "private": p[3], "aliases": p[4] if len(p) > 4 else []})
    dump("places_costs.json", places)
    ids = [t["id"] for t in TOURS]
    assert len(ids) == len(set(ids)), "duplicate tour ids"
    dump("tours.json", {
        "checked": CHECKED,
        "tours": TOURS,
        "bands": [{"keywords": k, "label": l, "budget": b} for k, l, b in BANDS],
        "countryFactor": COUNTRY_FACTOR,
        "flashpackerMultiplier": 1.6,
        "defaultBudget": 20,
    })
    modes = {"flight", "bus", "train", "car", "ferry", "walk", "other", "sleeperTrain", "sleeperBus", "minibus", "slowBoat", "motorbike"}
    for r in ROUTES:
        assert r["mode"] in modes, r
    dump("transport_routes.json", {"checked": CHECKED, "routes": ROUTES, "fallback": FALLBACK})
    dump("fixed_costs.json", {"checked": CHECKED, "items": FIXED})
    print(f"{len(COUNTRIES)} countries, {len(places)} places, {len(TOURS)} tours, {len(ROUTES)} routes, {len(FIXED)} fixed costs")


if __name__ == "__main__":
    main()
