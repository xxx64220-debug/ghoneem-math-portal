# SAT calculator deployment — 16 October 2026

The supported Desmos v1.12 GraphingCalculator API is loaded lazily only when both productionAuthorized=true and a nonempty project key are configured in web/sat-calculator-config.js (and matching dist file). Production defaults to disabled. No demonstration key is included. API failure preserves the official College Board calculator link.

Activation requires the portal owner to verify a Desmos production usage arrangement covering https://math.portal.ghoneem.com, obtain the corresponding production API key via https://www.desmos.com/my-api, and record that authorization before configuring and redeploying. A key alone does not prove licensing. A general API calculator must not be described as the exact College Board test configuration.

Inspection: no production Desmos key or authorization record found in repository or hosted source; Sites runtime environment is empty. This does not establish whether a separate off-platform contract exists.

Panel controls never modify exam state or call backend APIs. The calculator persists while hidden and during question navigation, and is destroyed at the next attempt. Nothing is stored in student records. Desktop supports native pointer resizing and keyboard-accessible Enlarge/Reduce; tablet/mobile use a stacked, vertically resizable panel. Close and Escape restore focus to the opener. Desmos accessibility settings retain their defaults.

Browser regression coverage: default-off, authorized synthetic SDK, failed SDK loading; desktop/tablet/mobile sizing; open/close/Escape; expression, answer and navigation persistence; deadline countdown continuity. All API calls in these tests are mocked; they do not certify actual Desmos availability or licensing.
