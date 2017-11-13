function [mpc]= load_shedding(mpc,per) %function load shedding

%input the case data mpc and the load shedding amount per such as 0.05

[mpc.bus] =scale_load((1-per), mpc.bus); %scale load function in mathpower scales the active and reactive loads
mpc.gen(:,2)=(1-per)*mpc.gen(:,2); %scale also the generation
end