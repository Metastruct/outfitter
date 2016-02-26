local Tag='costumizer' 

module(Tag,package.seeall)

util.AddNetworkString(Tag) 


function WantCostume(pl,mdl)
	pl.want_costume = mdl
end

function OnMessage(len,pl)
	
end

