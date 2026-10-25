# Where the built-in figures come from

All bundled prices are **typical 2025–26 backpacker figures in GBP, checked October 2026**. They are planning estimates, and every figure can be overridden in the app. Always confirm visa rules on [GOV.UK foreign travel advice](https://www.gov.uk/foreign-travel-advice) before booking.

Regenerate the data with:

```bash
python3 scripts/build_costs.py                  # costs, tours, routes, rules
python3 scripts/build_shapes.py ne50.geojson   # country outlines (Natural Earth 1:50m, public domain)
python3 scripts/build_data.py countries.json   # country facts (mledoze/countries, ODbL)
```

## Entry rules and visas (UK passport)
- **Thailand:** visa-free stays were cut from 60 to 30 days on 15 Sep 2026, and the TDAC arrival card is required.
  - [VisasNews](https://visasnews.com/en/thailand-to-officially-cut-visa-free-stay-to-30-days-on-september-15-2026/)
  - [Simba Sea Trips](https://simbaseatrips.com/blog/thailand/thailand-entry-requirements/)
- **Vietnam:** 45 days visa-free until March 2028. The e-visa is $25 for a single entry or $50 for multiple entries.
  - [vietnam-visa.org](https://www.vietnam-visa.org/visa/united-kingdom-citizens.html)
  - [evisasvietnam.com](https://evisasvietnam.com/blog/vietnam-e-visa-for-uk-citizens-do-you-need-one-or-can-you-stay-45-days-free/)
- **Cambodia:** visa on arrival is $30, the e-visa is about $36, and the e-Arrival card is free.
  - [backpackingtours.com](https://www.backpackingtours.com/blog/cambodia-visa-requirements-what-you-need-to-know)
  - [holidaysg.com](https://holidaysg.com/blogs/cambodia-visa-fees-costs-2026)
- **Laos:** visa on arrival is US$40 according to [GOV.UK – living in Laos](https://gov.uk/guidance/living-in-laos).
- **Indonesia:** the e-VOA is IDR 500,000, plus the All Indonesia arrival card and a Bali levy of IDR 150,000. See this [ACM news report](https://www.jimboombatimes.com.au/story/9137756/new-entry-rules-for-australians-travelling-to-bali/). The new criminal code is covered by [X-Ray Mag](https://xray-mag.com/content/indonesia-bans-sex-outside-marriage).
- **Malaysia (MDAC), Singapore (SG Arrival Card) and the Philippines (eTravel):**
  - [dmcquote.com SEA visa guide](https://dmcquote.com/blog/post/southeast-asia-visa-guide-2026)
  - [GOV.UK Philippines](https://gov.uk/foreign-travel-advice/philippines/entry-requirements)
- **Myanmar:** an e-visa of about US$50 is needed, and the FCDO advises against travel to parts of the country.
  - [Wikipedia – visa policy of Myanmar](https://en.wikipedia.org/wiki/Visa_policy_of_Myanmar)
  - [GOV.UK Myanmar](https://www.gov.uk/foreign-travel-advice/myanmar/entry-requirements)

## Laws and driving
- **Thailand vape ban:**
  - [Fox News, Apr 2026](https://www.foxnews.com/travel/vacation-hot-spot-cracks-down-vaping-jail-threats-hefty-fines.amp)
  - [Goods Across Borders](https://goodsacrossborders.com/traveling/can-i-bring/vape-e-cigarette/to/thailand)
- **Vietnam vape ban:**
  - [SAYS](https://says.com/my/news/vietnam-nationwide-vape-ban)
  - [Asian Trails](https://www.asiantrails.travel/?p=1041666)
- **Vietnam licence rules:** Vietnam only accepts the 1968 IDP, and riding without one is fined 2–4 million VND.
  - [vietnamtourism.com](https://www.vietnamtourism.com/en/international-driving-permit-for-motorbikes-in-vietnam-what-your-license-really-covers)
  - [goasia.cc](https://goasia.cc/en/news/vietnam-motorbike-rental-valid-licence-rules)
- **International Driving Permit:** £5.50 at the Post Office, per [this May 2026 guide](https://www.kaeltripton.com/uk-driving-licence-abroad/).

## Daily costs and accommodation
- **Daily budgets by country:**
  - [Mad Monkey Hostels – SEA 2026](https://madmonkeyhostels.com/blogs/the-first-timers-guide-to-travelling-southeast-asia-in-2026/)
  - [DMC Quote – SEA trip cost 2026](https://dmcquote.com/blog/post/southeast-asia-trip-cost-2026)
  - [TravelBuzzy](https://www.travelbuzzy.com/backpacking-southeast-asia-guide-2026)
  - [XRWXV](https://xrwxv.com/backpacking-southeast-asia-budget/)
  - [TravelValueFinder](https://travelvaluefinder.com/backpacking-southeast-asia-budget/)
- **Dorm prices:**
  - [Mad Monkey – SEA on $30 a day](https://madmonkeyhostels.com/blogs/how-to-travel-southeast-asia-on-30-a-day-and-where-its-actually-possible/)
  - [Lub d hostel deals guide](https://lubd.com/scoop/how-to-find-the-best-hostel-deals-5-budget-travel-tips-for-backpackers-in-southeast-asia-2025-guide/)
  - [Travel Arbitrage SEA budget 2026](https://www.travelarbitrage.net/en/blog/southeast-asia-backpacker-budget-2026)

## Tours
- **Ha Giang Loop:**
  - [Wise guide](https://wise.com/sg/blog/ha-giang-loop-guide)
  - [backpackmoments](https://backpackmoments.com/ha-giang-loop/)
  - [Jonny Melon](https://www.jonnymelon.com/ha-giang-loop/)
- **Ha Long / Lan Ha cruises:**
  - [travelguidestip](https://travelguidestip.com/halong-bay-travel-guide/)
  - [machupicchu.org Ha Long budget](https://www.machupicchu.org/ha-long-bay-budget-guide-2026-complete-cost-breakdown.htm)
- **Khao Sok:**
  - [TourRadar](https://www.tourradar.com/t/366245)
  - [Expedia listings](https://www.expedia.com/things-to-do/cheow-lan-lake-tour-with-cave-and-rafthouse-from-khao-lak.a50907532.activity-details)
- **Angkor passes** ($37 for one day, $62 for three): [helloangkor](https://helloangkor.com/angkor-ticket-prices/)
- **El Nido** (₱400 environmental fee): [suroy.ph](https://suroy.ph/el-nido-travel-guide/)
- **Everything else:** typical 2025–26 prices from GetYourGuide, Klook, 12Go and backpacker blogs.

## Transport
- **Bangkok–Chiang Mai sleeper train:**
  - [train36](https://www.train36.com/bangkok-to-chiang-mai-train.html)
  - [The Backpacking Family](https://thebackpackingfamily.com/how-to-travel-from-bangkok-to-chiang-mai/)
- **Laos slow boat**, 600,000–750,000 kip as of May 2026: [Travelers & Dreamers](https://travelersanddreamers.com/slow-boat-from-luang-prabang/)
- **Hanoi–Hue train:** [vietnamtourism.com](https://www.vietnamtourism.com/en/transport/hanoi-hue)
- **Other legs:** typical 12Go, Seat61 and Rome2Rio prices.

## Fixed costs
- **Vaccines:**
  - [TreatCompare – UK travel clinic prices](https://www.treatcompare.com/travel-clinic)
  - [VSM Pharmacy price list](https://vsmpharmacy.co.uk/?p=21484)
- **Insurance:**
  - [MoneyGeek](https://www.moneygeek.com/insurance/travel/coverage/backpacker-gap-year/)
  - [Backpacking Is Life](https://backpackingislife.com/best-travel-insurance-for-backpackers/)
- **eSIMs:**
  - [vietnamtourism.com Airalo prices](https://www.vietnamtourism.com/en/esim/airalo)
  - [Saily](https://saily.com/blog/airalo-esim-pricing/)
- **Flights:** London–Bangkok returns are typically £450–750, from [Skyscanner](https://www.skyscanner.co.za/routes/lond/bkkt/london-to-bangkok.html).
