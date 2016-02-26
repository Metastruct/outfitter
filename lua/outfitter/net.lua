local Tag='costumizer' 

module(Tag,package.seeall)

--function NET(func,targets)
--	net.Start(Tag)
--	func(targets)
--	if SERVER and targets then
--		net.Send(targets)
--	elseif SERVER and not targets then
--		net.Broadcast()
--	elseif CLIENT then
--		net.SendToServer()
--	else error"wtf" end
--end

net.new(Tag,self,"net") 
	
	:sv "request"

	:cl "response"
