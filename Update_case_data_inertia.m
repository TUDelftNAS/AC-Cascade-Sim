function [mpc_array ,island_cont]= Update_case_data_inertia(mpc, Branch_loading)
%inputs
%mpc: case data (whose links to be removed or has been removed)
%branch_loading: current iteration loading of the links
%outputs
%mpc_array: struct data containing the current stage islands
%islands_cont: 1 or 0 : 1 if islands cont to iterate; 0 if island is dead
%v2 updated: if there is no node loss due to link removals, than do not
%change the previous generation and load pattern


define_constants; %matpower numbers

%remove the links which are overloaded
mpc.branch(Branch_loading>=100, BR_STATUS)=0;

%and give some information to the user
for i=1:size(Branch_loading,1)
    if Branch_loading(i,1)>=100
   fprintf('Link %d between nodes %d and %d is overloaded.\n', mpc.branch(i,RATE_B), mpc.branch(i,T_BUS) ,mpc.branch(i,F_BUS) );
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
                            %close the generators starting from the
                            %smallesy
                        
         P_max_generators= (sortrows([mpc_array{1,i}.gen(:,1) mpc_array{1,i}.gen(:,PG)],2));   
         needed_load_shed=-P_load{1,i}+ P_gen{1,i}*(1-loss_factor) ;
         B = cumsum(P_max_generators(:,2)); %accum sum starting from the smallest gen
         %if needed load shed is more than the accumgen, kill all
         %generators
         if needed_load_shed>=B(end)
%          mpc_array{1,i}.gen(:,2)=0; 
%          mpc_array{1,i}.gen(:,8)=0;  %generator status out all and island does not cont
       mpc_array{1,i}.gen(:,:)=[];  
island_cont(1,i)=0;
         else
         lost_gen=[P_max_generators((B<needed_load_shed),1);P_max_generators(P_max_generators(:,2)==(min(P_max_generators(B>needed_load_shed,2))),1)];  
%          mpc_array{1,i}.gen( ismember(mpc_array{1,i}.gen(:,1),lost_gen),8)=0;
%          mpc_array{1,i}.gen( ismember(mpc_array{1,i}.gen(:,1),lost_gen),2)=0;
  mpc_array{1,i}.gen( ismember(mpc_array{1,i}.gen(:,1),lost_gen),:)=[]; %burda da gen kaldimi bakmaliyim
  if isempty( mpc_array{1,i}.gen(:,:) )
   island_cont(1,i)=0;
  end
         end
        else
        %close the loads (both active and reactive) starting from smallest
        
         P_max_generators= (sortrows([mpc_array{1,i}.bus(:,1) mpc_array{1,i}.bus(:,3)],2));   
         needed_load_shed= P_load{1,i}- P_gen{1,i}*(1-loss_factor) ;
         B = cumsum(P_max_generators(:,2)); %accum sum starting from the smallest gen
         %if needed load shed is more than the accumgen, kill all
         %generators
         if needed_load_shed>=B(end)%if there is not enough load shedding, total blackout  
         mpc_array{1,i}.bus(:,3)=0;
         mpc_array{1,i}.bus(:,4)=0;
         island_cont(1,i)=0;
         else
         lost_gen=[P_max_generators((B<needed_load_shed),1);P_max_generators(P_max_generators(:,2)==(min(P_max_generators(B>needed_load_shed,2))),1)];  
         mpc_array{1,i}.bus( ismember(mpc_array{1,i}.bus(:,1),lost_gen),3)=0;
         mpc_array{1,i}.bus( ismember(mpc_array{1,i}.bus(:,1),lost_gen),4)=0;
         end
         
         
        end
         end
    end
end


end
