# ItineraryMaster ✈️🗺️

A native iPhone app (SwiftUI) for planning and running a months-long gap year. It works offline, is installed by sideloading, and needs no accounts.

| Tab | What it does |
|---|---|
| **Map** | Your whole route on an interactive map, with numbered stops, travelled and planned legs, and pins for saved hostels and activities. Tap **+** to search for a place or drop a pin anywhere. |
| **Route** | Drag to reorder stops and swipe to skip or delete them. Set the nights for each stop and the dates update automatically. **Get back on route** lets you say where you are now and how long you're staying, and the rest of the trip moves to fit. |
| **Saved** | Your TikTok inbox. Share a TikTok to **Save to Itinerary** (or copy the link and tap **Paste**). The app gets the caption, creator and thumbnail. It then sorts the video on the device into itinerary, packing, activities, stays, work & volunteering, budget, food, transport, tips or visa, and spots the places and prices mentioned. In one tap you can link the video to a stop, add the place to your route, or send its packing items to your list. |
| **Packing** | Packing lists (starter lists for backpackers included) with packed progress, weights, product links and a "to buy" total. There's also a **To-do before I go** checklist. |
| **Budget** | Your total budget, what you've spent, what's left, and **how much you can spend per day** for the rest of the trip. The plan is each country's nights × its daily budget, plus flights, insurance, gear and travel between stops. You can log spending in any currency, and it's converted automatically. Includes charts and a currency converter. |

Every **place** has:
- photos (from your library or camera) and a Wikipedia summary with a picture
- lists for **Where to stay · Volunteer & work · Activities & tours · Food · Sights**, each with price, link, rating, booked flag and a map pin
- a "Find ideas" button that searches Hostelworld, Worldpackers, Workaway, GetYourGuide and similar sites
- its linked TikToks, your notes, and how you're getting there (mode, cost, Rome2Rio link)

Every **country** has offline facts, your daily budget for it, GOV.UK visa and safety links, and your notes and videos. The offline facts are:
- capital, currency (with the live rate), languages and calling code
- plug types and which side of the road they drive on
- emergency numbers, tipping customs and the best time to visit
- the typical daily cost for a backpacker

### Offline
Everything you add is stored on your phone, along with the country guides, packing lists, budget maths (using the last saved exchange rates) and route editing, so none of these need signal. These need internet: map tiles for areas you haven't looked at yet, searching for new places, downloading TikTok details, Wikipedia info and updating exchange rates. Links you save offline are kept and processed automatically once you're back online.

---

## Install on your iPhone (iLoader / SideStore)

1. Go to **[Releases → latest](https://github.com/HrrymGames/ItineraryMaster/releases/latest)** and download `ItineraryMaster.ipa`.
2. Install it with **iLoader**, or in **SideStore** tap **+** and pick the IPA. It's signed with your own Apple ID.
3. Open TikTok, tap **Share → More**, and switch on **Save to Itinerary**. Adding it to your favourites keeps it near the front.

Free Apple IDs need the app refreshed every **7 days**. Refresh it in SideStore and your data stays. Before you delete or reinstall the app, use **More → Export backup**.

The share extension uses an App Group to hand links to the app. If your sideloading tool doesn't set the group up, the extension copies the link instead, and you finish by tapping **Paste** in the Saved tab.

## How it's built

```
App/                 SwiftUI app (SwiftData models, features per tab, services)
Shared/              Code shared with the share extension (link queue)
ShareExtension/      "Save to Itinerary" share-sheet extension
Packages/ItineraryCore/  Pure-Swift logic + unit tests: route scheduling, budget maths,
                     currency conversion, caption parser, backup format
scripts/build_data.py    Regenerates the bundled country & place datasets
project.yml          XcodeGen project spec
```

Every push runs **GitHub Actions**, which:
- runs the core tests (`swift test`) on Linux
- builds an unsigned `.ipa` on macOS. The entitlements are embedded with `ldid` so SideStore can sign it.
- launches the app in the iOS Simulator with demo data and takes screenshots
- publishes the IPA to the `latest` release

To build it locally on a Mac:

```bash
brew install xcodegen
xcodegen generate
open ItineraryMaster.xcodeproj
```

Data credits: country basics come from [mledoze/countries](https://github.com/mledoze/countries) (ODbL), place summaries from Wikipedia, and exchange rates from open.er-api.com and Frankfurter. Always check visa and safety rules on GOV.UK before you travel.
