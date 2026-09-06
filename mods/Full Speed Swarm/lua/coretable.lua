if core then
	core:module('CoreTable')
end

function table.icontains(tbl, e)
	local nr = #tbl

	for i = 1, nr do
		if tbl[i] == e then
			return i
		end
	end

	return false
end
