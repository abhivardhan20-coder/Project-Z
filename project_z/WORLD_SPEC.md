# World specification

One Godot unit equals one metre. The terrain spans X and Z from −500 m through +500 m. X+ points east, Z− north, and Y+ up. The deterministic seed is 1790805. One hundred 100 m blocks share edge elevations at both detail levels. There are two central arterials and six additional streets in each direction, forming a connected grid with multiple loops and hillside curves.

| District | Quadrant | Selected playable locations |
| --- | --- | --- |
| Hillview Residential | Northwest | Hillview Steps, Corner Shop, Fern Court |
| Civic & Commercial | Northeast | Civic Police Annex, municipal hall exterior, emergency parking, evacuation memorial |
| Old Market | Southwest | Northline Grocer, Mercy Clinic, relief hall exterior, pharmacy frontage |
| Utility & Industrial | Southeast | Bank Pumping Station, Kaldran Freight, Municipal Motor Works, electrical service yard and fuel depot exteriors |

P06 follows the Hillview collector from X −380 to −140. Both sides have a curb transition near the shop. The imported apartment facade and shop entrance have explicit collision. The bridge carries a continuous deck across the drainage cut. The district roads, live map and parcel placement read from the same axis definitions. The district shader mirrors those road curves for continuous paving.

The standard player capsule is 0.56 m in diameter and 1.75 m tall. New interiors use 1.19 m doors and 2.15 m door leaves. The surrounding terrain is graded into their approaches. Two new interiors have lofts in addition to Hillview Steps' existing upper floors.
