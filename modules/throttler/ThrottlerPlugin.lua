ThrottlerPlugin = Class({
	Active = true,
	__init = function(self)
		self.projects = {}
	end,
	sort = function(self)
		table.sort(self.projects, self._sortProjects)
	end,
	UnpausedCount = 0,
})