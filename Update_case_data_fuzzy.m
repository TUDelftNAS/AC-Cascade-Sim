function [mpc_array ,island_cont, tripped_due_to_fuzzy]= Update_case_data_fuzzy(mpc, Branch_loading)
%inputs
%mpc: case data (whose links to be removed or has been removed)
%branch_loading: current iteration loading of the links
%outputs
%mpc_array: struct data containing the current stage islands
%islands_cont: 1 or 0 : 1 if islands cont to iterate; 0 if island is dead
%v2 updated: if there is no node loss due to link removals, than do not
%change the previous generation and load pattern


define_constants; %matpower numbers
transient_tr=80; %transient trashold
%remove the links which are overloaded
mpc.branch(Branch_loading>=100, BR_STATUS)=0;

%and give some information to the user
for i=1:size(Branch_loading,1)
    if Branch_loading(i,1)>=100
   fprintf('Link %d between nodes %d and %d is overloaded.\n', mpc.branch(i,RATE_B), mpc.branch(i,T_BUS) ,mpc.branch(i,F_BUS) );
    end
end


%due to transients trippings:

%and give some information to the user
tripped_due_to_fuzzy=[];
dummy=1;

for i=1:size(Branch_loading,1)
    if  (Branch_loading(i,1)>=transient_tr &&  Branch_loading(i,1)<100) 
   if rand(1)< ((Branch_loading(i,1)-80)/20) %fuzzy failure
   mpc.branch(i, BR_STATUS)=0;
   tripped_due_to_fuzzy(dummy,1)=mpc.branch(i,RATE_B);
   fprintf('Link %d between nodes %d and %d is tripped due to transients.\n', mpc.branch(i,RATE_B), mpc.branch(i,T_BUS) ,mpc.branch(i,F_BUS) );
   dummy=dummy+1;
   end
    end
end

 




%find the groups and isolated nodes. 
%NOTE: the bus numbering in groups and isolated is not correct!
% it uses the internal bus numbers. So be careful.
%numbering works correct with extract_islands

[groups ,isolated] = find_islands(mpc); 
num_islands=size(groups,2);

for i=1:size (isolated,2)
groups{1,num_islands+i}=isolated(1,i);
end

mpc_array = extract_islands(mpc, groups); %find the islands in the current stage


P_load=cell(1, size(mpc_array,2));
P_gen=cell(1, size(mpc_array,2));
island_cont=zeros(1,size(mpc_array,2));

for i=1:size(mpc_array,2)
P_load{1,i}=sum(mpc_array{1,i}.bus(:,PD)); %Calculate the total load in islands
P_gen{1,i}=sum(mpc_array{1,i}.gen(:,PG));
if P_load{1,i}>0 && P_gen {1,i}>0
    island_cont(1,i)=1; %check whether the case cont or not
    %case cont if there is both load and generation
end
end

%Assign every island a slack bus 
%first check whether there is slack bus or not: If it is
%there, do nothing

for i=1:size(mpc_array,2)
  if  any(mpc_array{1,i}.bus(:,BUS_TYPE)==3)>0% if there is slack bus do nothing
  else
      %find the generators in the islands and their output power, sorty
      %the output powers in decreasing order
   P_max_generators= flipud(sortrows([mpc_array{1,i}.gen(:,1) mpc_array{1,i}.gen(:,PG)],2));    
        
    if ~isempty(P_max_generators)
    %assign the one with maximum power output as slack bus
    mpc_array{1,i}.bus(find(mpc_array{1,i}.bus(:,1)==P_max_generators(1,1)),BUS_TYPE)=3;
    end
   end
end

 loss_factor=0;
%loss_factor=0.03; %to pre-allocate a loss factor for the active power losses
%if it is greater than 0, say 0.2; 10% of the current generation will be
%allocated for the losses

for i=1:size(mpc_array,2) %for all islands
 
  
    if island_cont(1,i)>0   %if the island continues
         %v2 updated:
         if sum(mpc_array{1,i}.bus(:,2)~=4)<sum(mpc.bus(:,2)~=4) %do the generation demand balancing, only if there is node loss
        if P_load{1,i}< P_gen{1,i}*(1-loss_factor) %if load is smaller than the genaration there
        %scale down the generators
         mpc_array{1,i}.gen(:,PG)=mpc_array{1,i}.gen(:,PG).*( (1+loss_factor)* P_load{1,i}/P_gen{1,i});
        else
        %scale down the loads (both active and reactive)
        mpc_array{1,i}.bus(:,PD)=((1-loss_factor)* P_gen{1,i}/P_load{1,i})*mpc_array{1,i}.bus(:,PD);
        mpc_array{1,i}.bus(:,QD)=((1-loss_factor)* P_gen{1,i}/P_load{1,i})*mpc_array{1,i}.bus(:,QD);
        end
         end
    end
end


end