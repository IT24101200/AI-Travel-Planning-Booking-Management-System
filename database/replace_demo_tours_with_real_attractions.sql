-- Replace 50 unused fictional tours with researched real attractions.

-- Prices, currencies, start times and durations remain your configured values.

-- Coordinate sources are recorded in real_tour_locations.json.

-- Data derived from OpenStreetMap is attributed to its contributors (ODbL).

BEGIN;

UPDATE "Tours" SET "Name" = 'Udawattakele Forest Walk', "Category" = 'Nature', "Description" = 'Walk through the forest reserve above Kandy. Forest trails are explored on foot.', "Latitude" = 7.2989000, "Longitude" = 80.6429000, "UpdatedAt" = NOW() WHERE "Id" = 72 AND "Name" = 'Demo Kandy Heritage Walk' AND "DestinationId" = 41;

UPDATE "Tours" SET "Name" = 'Ranawana Rajamaha Viharaya Visit', "Category" = 'Culture', "Description" = 'Visit Ranawana temple near Pilimathalawa and explore its Buddhist sculptures.', "Latitude" = 7.2714139, "Longitude" = 80.5641156, "UpdatedAt" = NOW() WHERE "Id" = 73 AND "Name" = 'Demo Kandy Local Food Experience' AND "DestinationId" = 41;

UPDATE "Tours" SET "Name" = 'Lankatilaka Temple Visit', "Category" = 'Culture', "Description" = 'Explore Lankatilaka Raja Maha Viharaya in the Kandy district.', "Latitude" = 7.2339083, "Longitude" = 80.5650427, "UpdatedAt" = NOW() WHERE "Id" = 74 AND "Name" = 'Demo Kandy Nature Walk' AND "DestinationId" = 41;

UPDATE "Tours" SET "Name" = 'Gadaladeniya Temple Visit', "Category" = 'Culture', "Description" = 'Visit Gadaladeniya temple near Pilimathalawa.', "Latitude" = 7.2572700, "Longitude" = 80.5561355, "UpdatedAt" = NOW() WHERE "Id" = 75 AND "Name" = 'Demo Kandy Craft Workshop' AND "DestinationId" = 41;

UPDATE "Tours" SET "Name" = 'Embekka Devalaya Woodcarving Visit', "Category" = 'Culture', "Description" = 'Explore the carved wooden pillars and shrine complex at Embekka Devalaya.', "Latitude" = 7.2179167, "Longitude" = 80.5676111, "UpdatedAt" = NOW() WHERE "Id" = 76 AND "Name" = 'Demo Kandy Evening City Walk' AND "DestinationId" = 41;

UPDATE "Tours" SET "Name" = 'Galle Lighthouse Coastal Walk', "Category" = 'Heritage', "Description" = 'Walk along the fort coastline near Galle Lighthouse.', "Latitude" = 6.0245483, "Longitude" = 80.2193733, "UpdatedAt" = NOW() WHERE "Id" = 77 AND "Name" = 'Demo Galle Heritage Walk' AND "DestinationId" = 35;

UPDATE "Tours" SET "Name" = 'Dutch Reformed Church Visit', "Category" = 'Heritage', "Description" = 'Visit the Dutch Reformed Church inside Galle Fort.', "Latitude" = 6.0281645, "Longitude" = 80.2171268, "UpdatedAt" = NOW() WHERE "Id" = 78 AND "Name" = 'Demo Galle Local Food Experience' AND "DestinationId" = 35;

UPDATE "Tours" SET "Name" = 'Galle National Maritime Museum Visit', "Category" = 'Culture', "Description" = 'Explore the maritime museum in the historic Dutch warehouse inside Galle Fort.', "Latitude" = 6.0281548, "Longitude" = 80.2184438, "UpdatedAt" = NOW() WHERE "Id" = 79 AND "Name" = 'Demo Galle Nature Walk' AND "DestinationId" = 35;

UPDATE "Tours" SET "Name" = 'Japanese Peace Pagoda Visit', "Category" = 'Culture', "Description" = 'Visit the Japanese Peace Pagoda at Rumassala near Unawatuna.', "Latitude" = 6.0158561, "Longitude" = 80.2379092, "UpdatedAt" = NOW() WHERE "Id" = 80 AND "Name" = 'Demo Galle Craft Workshop' AND "DestinationId" = 35;

UPDATE "Tours" SET "Name" = 'Unawatuna Beach Walk', "Category" = 'Nature', "Description" = 'Enjoy a coastal walk along Unawatuna Beach near Galle.', "Latitude" = 6.0081669, "Longitude" = 80.2443683, "UpdatedAt" = NOW() WHERE "Id" = 81 AND "Name" = 'Demo Galle Evening City Walk' AND "DestinationId" = 35;

UPDATE "Tours" SET "Name" = 'Nine Arch Bridge Walk', "Category" = 'Sightseeing', "Description" = 'Walk from the mapped parking area to the Nine Arch Bridge near Ella.', "Latitude" = 6.8789299, "Longitude" = 81.0613600, "UpdatedAt" = NOW() WHERE "Id" = 82 AND "Name" = 'Demo Ella Heritage Walk' AND "DestinationId" = 34;

UPDATE "Tours" SET "Name" = 'Little Adam''s Peak Hike', "Category" = 'Nature', "Description" = 'Hike to Little Adam''s Peak near Ella. The summit is reached on foot.', "Latitude" = 6.8650500, "Longitude" = 81.0630167, "UpdatedAt" = NOW() WHERE "Id" = 83 AND "Name" = 'Demo Ella Local Food Experience' AND "DestinationId" = 34;

UPDATE "Tours" SET "Name" = 'Ella Rock Hike', "Category" = 'Nature', "Description" = 'Hike to the Ella Rock viewpoint. The summit is reached on foot.', "Latitude" = 6.8550355, "Longitude" = 81.0523841, "UpdatedAt" = NOW() WHERE "Id" = 84 AND "Name" = 'Demo Ella Nature Walk' AND "DestinationId" = 34;

UPDATE "Tours" SET "Name" = 'Ravana Falls Viewpoint Visit', "Category" = 'Nature', "Description" = 'View Ravana Falls beside the Ella-Wellawaya road.', "Latitude" = 6.8411694, "Longitude" = 81.0550963, "UpdatedAt" = NOW() WHERE "Id" = 85 AND "Name" = 'Demo Ella Craft Workshop' AND "DestinationId" = 34;

UPDATE "Tours" SET "Name" = 'Dhowa Rock Temple Visit', "Category" = 'Culture', "Description" = 'Visit Dhowa Rajamaha Viharaya on the Bandarawela-Ella route.', "Latitude" = 6.8562524, "Longitude" = 81.0222394, "UpdatedAt" = NOW() WHERE "Id" = 86 AND "Name" = 'Demo Ella Evening City Walk' AND "DestinationId" = 34;

UPDATE "Tours" SET "Name" = 'Victoria Park Garden Walk', "Category" = 'Nature', "Description" = 'Walk through Victoria Park in Nuwara Eliya.', "Latitude" = 6.9694837, "Longitude" = 80.7683193, "UpdatedAt" = NOW() WHERE "Id" = 87 AND "Name" = 'Demo Nuwara Eliya Heritage Walk' AND "DestinationId" = 45;

UPDATE "Tours" SET "Name" = 'Gregory Lake Park Walk', "Category" = 'Nature', "Description" = 'Explore the lakeside recreation area at Gregory Lake Park.', "Latitude" = 6.9622884, "Longitude" = 80.7723637, "UpdatedAt" = NOW() WHERE "Id" = 88 AND "Name" = 'Demo Nuwara Eliya Local Food Experience' AND "DestinationId" = 45;

UPDATE "Tours" SET "Name" = 'Hakgala Botanical Garden Visit', "Category" = 'Nature', "Description" = 'Explore Hakgala Botanical Garden. The meeting location is the mapped garden parking area.', "Latitude" = 6.9270754, "Longitude" = 80.8224067, "UpdatedAt" = NOW() WHERE "Id" = 89 AND "Name" = 'Demo Nuwara Eliya Nature Walk' AND "DestinationId" = 45;

UPDATE "Tours" SET "Name" = 'Seetha Amman Temple Visit', "Category" = 'Culture', "Description" = 'Visit Seetha Amman Kovil at Seetha Eliya near Nuwara Eliya.', "Latitude" = 6.9332089, "Longitude" = 80.8106456, "UpdatedAt" = NOW() WHERE "Id" = 90 AND "Name" = 'Demo Nuwara Eliya Craft Workshop' AND "DestinationId" = 45;

UPDATE "Tours" SET "Name" = 'Galway''s Land Nature Walk', "Category" = 'Nature', "Description" = 'Explore the forest trails at Galway''s Land National Park on foot.', "Latitude" = 6.9657876, "Longitude" = 80.7780162, "UpdatedAt" = NOW() WHERE "Id" = 91 AND "Name" = 'Demo Nuwara Eliya Evening City Walk' AND "DestinationId" = 45;

UPDATE "Tours" SET "Name" = 'Sigiriya Museum Visit', "Category" = 'Culture', "Description" = 'Explore the museum near the Sigiriya archaeological site.', "Latitude" = 7.9569719, "Longitude" = 80.7515730, "UpdatedAt" = NOW() WHERE "Id" = 92 AND "Name" = 'Demo Sigiriya Heritage Walk' AND "DestinationId" = 46;

UPDATE "Tours" SET "Name" = 'Pidurangala Rock Hike', "Category" = 'Nature', "Description" = 'Hike to Pidurangala Rock near Sigiriya. The summit is reached on foot.', "Latitude" = 7.9662102, "Longitude" = 80.7616977, "UpdatedAt" = NOW() WHERE "Id" = 93 AND "Name" = 'Demo Sigiriya Local Food Experience' AND "DestinationId" = 46;

UPDATE "Tours" SET "Name" = 'Dambulla Cave Temple Visit', "Category" = 'Culture', "Description" = 'Visit the cave temple complex at Dambulla on an excursion from Sigiriya.', "Latitude" = 7.8566286, "Longitude" = 80.6484958, "UpdatedAt" = NOW() WHERE "Id" = 94 AND "Name" = 'Demo Sigiriya Nature Walk' AND "DestinationId" = 46;

UPDATE "Tours" SET "Name" = 'Minneriya National Park Safari', "Category" = 'Safari', "Description" = 'Visit Minneriya National Park from the mapped visitor information point. Confirm park admission and safari vehicle arrangements before departure.', "Latitude" = 8.0327164, "Longitude" = 80.8236120, "UpdatedAt" = NOW() WHERE "Id" = 95 AND "Name" = 'Demo Sigiriya Craft Workshop' AND "DestinationId" = 46;

UPDATE "Tours" SET "Name" = 'Kaudulla National Park Safari', "Category" = 'Safari', "Description" = 'Visit Kaudulla National Park from its mapped entrance. Confirm park admission and safari vehicle arrangements before departure.', "Latitude" = 8.1341492, "Longitude" = 80.8775612, "UpdatedAt" = NOW() WHERE "Id" = 96 AND "Name" = 'Demo Sigiriya Evening City Walk' AND "DestinationId" = 46;

UPDATE "Tours" SET "Name" = 'Jaya Sri Maha Bodhi Visit', "Category" = 'Culture', "Description" = 'Visit the sacred Bodhi tree complex in Anuradhapura.', "Latitude" = 8.3447251, "Longitude" = 80.3974552, "UpdatedAt" = NOW() WHERE "Id" = 97 AND "Name" = 'Demo Anuradhapura Heritage Walk' AND "DestinationId" = 47;

UPDATE "Tours" SET "Name" = 'Ruwanwelisaya Stupa Visit', "Category" = 'Culture', "Description" = 'Visit Ruwanwelisaya in the sacred city of Anuradhapura.', "Latitude" = 8.3500003, "Longitude" = 80.3963970, "UpdatedAt" = NOW() WHERE "Id" = 98 AND "Name" = 'Demo Anuradhapura Local Food Experience' AND "DestinationId" = 47;

UPDATE "Tours" SET "Name" = 'Jetavanaramaya Stupa Visit', "Category" = 'Heritage', "Description" = 'Explore the Jetavanaramaya stupa site in Anuradhapura.', "Latitude" = 8.3516411, "Longitude" = 80.4036530, "UpdatedAt" = NOW() WHERE "Id" = 99 AND "Name" = 'Demo Anuradhapura Nature Walk' AND "DestinationId" = 47;

UPDATE "Tours" SET "Name" = 'Abhayagiri Monastery Visit', "Category" = 'Heritage', "Description" = 'Explore Abhayagiri monastery and stupa. The meeting point is the mapped visitor car park.', "Latitude" = 8.3692316, "Longitude" = 80.3956506, "UpdatedAt" = NOW() WHERE "Id" = 100 AND "Name" = 'Demo Anuradhapura Craft Workshop' AND "DestinationId" = 47;

UPDATE "Tours" SET "Name" = 'Isurumuniya Temple Visit', "Category" = 'Culture', "Description" = 'Visit Isurumuniya temple in Anuradhapura, starting at the mapped car park.', "Latitude" = 8.3355732, "Longitude" = 80.3908857, "UpdatedAt" = NOW() WHERE "Id" = 101 AND "Name" = 'Demo Anuradhapura Evening City Walk' AND "DestinationId" = 47;

UPDATE "Tours" SET "Name" = 'Koneswaram Temple Visit', "Category" = 'Culture', "Description" = 'Visit Koneswaram temple on Swami Rock in Trincomalee.', "Latitude" = 8.5824400, "Longitude" = 81.2453800, "UpdatedAt" = NOW() WHERE "Id" = 102 AND "Name" = 'Demo Trincomalee Heritage Walk' AND "DestinationId" = 48;

UPDATE "Tours" SET "Name" = 'Fort Frederick Heritage Walk', "Category" = 'Heritage', "Description" = 'Explore the Fort Frederick area in Trincomalee.', "Latitude" = 8.5793044, "Longitude" = 81.2440475, "UpdatedAt" = NOW() WHERE "Id" = 103 AND "Name" = 'Demo Trincomalee Local Food Experience' AND "DestinationId" = 48;

UPDATE "Tours" SET "Name" = 'Kanniya Hot Water Wells Visit', "Category" = 'Sightseeing', "Description" = 'Visit the hot water wells at Kanniya near Trincomalee.', "Latitude" = 8.6044881, "Longitude" = 81.1713144, "UpdatedAt" = NOW() WHERE "Id" = 104 AND "Name" = 'Demo Trincomalee Nature Walk' AND "DestinationId" = 48;

UPDATE "Tours" SET "Name" = 'Nilaveli Beach Walk', "Category" = 'Nature', "Description" = 'Enjoy a coastal walk at Nilaveli Beach north of Trincomalee.', "Latitude" = 8.6980818, "Longitude" = 81.1929762, "UpdatedAt" = NOW() WHERE "Id" = 105 AND "Name" = 'Demo Trincomalee Craft Workshop' AND "DestinationId" = 48;

UPDATE "Tours" SET "Name" = 'Trincomalee Maritime Museum Visit', "Category" = 'Culture', "Description" = 'Visit the Maritime and Naval History Museum near Fort Frederick.', "Latitude" = 8.5698325, "Longitude" = 81.2374202, "UpdatedAt" = NOW() WHERE "Id" = 106 AND "Name" = 'Demo Trincomalee Evening City Walk' AND "DestinationId" = 48;

UPDATE "Tours" SET "Name" = 'Nallur Kandaswamy Temple Visit', "Category" = 'Culture', "Description" = 'Visit Nallur Kandaswamy temple in the Jaffna district.', "Latitude" = 9.6745677, "Longitude" = 80.0296641, "UpdatedAt" = NOW() WHERE "Id" = 107 AND "Name" = 'Demo Jaffna Heritage Walk' AND "DestinationId" = 49;

UPDATE "Tours" SET "Name" = 'Jaffna Fort Heritage Walk', "Category" = 'Heritage', "Description" = 'Explore the historic fort area in Jaffna.', "Latitude" = 9.6623353, "Longitude" = 80.0081655, "UpdatedAt" = NOW() WHERE "Id" = 108 AND "Name" = 'Demo Jaffna Local Food Experience' AND "DestinationId" = 49;

UPDATE "Tours" SET "Name" = 'Jaffna Public Library Visit', "Category" = 'Culture', "Description" = 'Visit the public library area in central Jaffna; interior access is subject to library rules.', "Latitude" = 9.6621715, "Longitude" = 80.0118084, "UpdatedAt" = NOW() WHERE "Id" = 109 AND "Name" = 'Demo Jaffna Nature Walk' AND "DestinationId" = 49;

UPDATE "Tours" SET "Name" = 'Keerimalai Springs Visit', "Category" = 'Sightseeing', "Description" = 'Visit the coastal freshwater springs at Keerimalai.', "Latitude" = 9.8148018, "Longitude" = 80.0111483, "UpdatedAt" = NOW() WHERE "Id" = 110 AND "Name" = 'Demo Jaffna Craft Workshop' AND "DestinationId" = 49;

UPDATE "Tours" SET "Name" = 'Naguleswaram Temple Visit', "Category" = 'Culture', "Description" = 'Visit Keerimalai Naguleswaram temple near the springs.', "Latitude" = 9.8134984, "Longitude" = 80.0125066, "UpdatedAt" = NOW() WHERE "Id" = 111 AND "Name" = 'Demo Jaffna Evening City Walk' AND "DestinationId" = 49;

UPDATE "Tours" SET "Name" = 'Batticaloa Fort Heritage Visit', "Category" = 'Heritage', "Description" = 'Visit the historic fort area in Batticaloa. Access to government premises is subject to local permission.', "Latitude" = 7.7117713, "Longitude" = 81.7019369, "UpdatedAt" = NOW() WHERE "Id" = 112 AND "Name" = 'Demo Batticaloa Heritage Walk' AND "DestinationId" = 50;

UPDATE "Tours" SET "Name" = 'Batticaloa Lighthouse Visit', "Category" = 'Sightseeing', "Description" = 'Visit the lighthouse area at Palameenmadu in Batticaloa.', "Latitude" = 7.7548402, "Longitude" = 81.6854255, "UpdatedAt" = NOW() WHERE "Id" = 113 AND "Name" = 'Demo Batticaloa Local Food Experience' AND "DestinationId" = 50;

UPDATE "Tours" SET "Name" = 'Kallady Beach Walk', "Category" = 'Nature', "Description" = 'Enjoy a coastal walk at Kallady Beach. The marker identifies a documented beach viewpoint.', "Latitude" = 7.7181389, "Longitude" = 81.7188639, "UpdatedAt" = NOW() WHERE "Id" = 114 AND "Name" = 'Demo Batticaloa Nature Walk' AND "DestinationId" = 50;

UPDATE "Tours" SET "Name" = 'St Mary''s Cathedral Visit', "Category" = 'Culture', "Description" = 'Visit St Mary''s Cathedral in Batticaloa.', "Latitude" = 7.7124456, "Longitude" = 81.6960228, "UpdatedAt" = NOW() WHERE "Id" = 115 AND "Name" = 'Demo Batticaloa Craft Workshop' AND "DestinationId" = 50;

UPDATE "Tours" SET "Name" = 'Pasikudah Beach Walk', "Category" = 'Nature', "Description" = 'Visit Pasikudah Beach on an excursion from Batticaloa.', "Latitude" = 7.9294868, "Longitude" = 81.5613931, "UpdatedAt" = NOW() WHERE "Id" = 116 AND "Name" = 'Demo Batticaloa Evening City Walk' AND "DestinationId" = 50;

UPDATE "Tours" SET "Name" = 'Gangaramaya Temple Visit', "Category" = 'Culture', "Description" = 'Visit Gangaramaya temple in central Colombo.', "Latitude" = 6.9166446, "Longitude" = 79.8566559, "UpdatedAt" = NOW() WHERE "Id" = 117 AND "Name" = 'Demo Colombo Heritage Walk' AND "DestinationId" = 51;

UPDATE "Tours" SET "Name" = 'Colombo National Museum Visit', "Category" = 'Culture', "Description" = 'Explore the National Museum of Colombo in Cinnamon Gardens.', "Latitude" = 6.9104168, "Longitude" = 79.8609194, "UpdatedAt" = NOW() WHERE "Id" = 118 AND "Name" = 'Demo Colombo Local Food Experience' AND "DestinationId" = 51;

UPDATE "Tours" SET "Name" = 'Independence Memorial Hall Visit', "Category" = 'Heritage', "Description" = 'Visit Independence Memorial Hall and its surrounding square in Colombo.', "Latitude" = 6.9040669, "Longitude" = 79.8676301, "UpdatedAt" = NOW() WHERE "Id" = 119 AND "Name" = 'Demo Colombo Nature Walk' AND "DestinationId" = 51;

UPDATE "Tours" SET "Name" = 'Galle Face Green Coastal Walk', "Category" = 'Nature', "Description" = 'Walk along the seafront promenade at Galle Face Green.', "Latitude" = 6.9249607, "Longitude" = 79.8444586, "UpdatedAt" = NOW() WHERE "Id" = 120 AND "Name" = 'Demo Colombo Craft Workshop' AND "DestinationId" = 51;

UPDATE "Tours" SET "Name" = 'Viharamahadevi Park Walk', "Category" = 'Nature', "Description" = 'Explore Viharamahadevi Park in Cinnamon Gardens, Colombo.', "Latitude" = 6.9138226, "Longitude" = 79.8614842, "UpdatedAt" = NOW() WHERE "Id" = 121 AND "Name" = 'Demo Colombo Evening City Walk' AND "DestinationId" = 51;

COMMIT;
