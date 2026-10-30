// Worker builds preserve public inputs here; older static checkouts use dist.
module.exports=require('node:fs').existsSync('portal-static')?'portal-static':'dist';
