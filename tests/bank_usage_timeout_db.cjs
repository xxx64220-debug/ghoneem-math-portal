// Reuse the established synthetic staff/group/score fixture, then compare the
// exact production helper with its replacement before running the base suite.
process.env.BANK_USAGE_TIMEOUT_CHECK='1';
require('./portal_management_db.cjs');
