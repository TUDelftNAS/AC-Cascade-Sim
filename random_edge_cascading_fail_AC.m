%simulates  cascading failure scenerio of every link failure with AC load
%flow

%you need load_sheeding.m
%you need load Calculate_S_links.m
%you need load update_case_data_v2.m > this function is changed comparing
%to the previous version
% add path to your matpower



%input: alpha (line tolerance parameter) , mpc (case data), lineThreat
        %(initial line attacks), nodeThreat (initial node attacks), 
        %thres(defines a threshold for the initial capacity of links)

clear
clc
close all
addpath('......\matpower') % add path to your matpower
% addpath(..... %folder optional

%if matlab plots graph is low quality, you can use this to fix it
% opengl hardware
% opengl info
% opengl software


define_constants; %to define the indices for the constants in matpower

%load the case, it includes the bus, branch, generator data. Initial
%network always starts from bus 1 with consequative numbering
%In addition base case generation and load are assumed to be somewhat
%evenly distributed.
%assuming every brach, gen are in service
 
 %mpc = loadcase(case30); %IEEE 30
 %mpc = loadcase(case57); %IEEE 57
 mpc = loadcase(case118); %IEEE 118
%load('IEEE300_busses_renumbered.mat'); %IEEE 300 busses are renumbered with ext2int 



%Fields that we don't use (Related to an error in ext2int and int2ext conversion), you are removing those fields if they exists
if isfield(mpc,'areas')
    mpc = rmfield(mpc, 'areas');
end
if isfield(mpc,'gencost')
    mpc = rmfield(mpc, 'gencost');
end

mpopt = mpoption( 'out.all', 0, 'pf.nr.max_it', 50); %to turn off the writings on the matlab command window and to inrease the iteration number to 50 ( default is 10)
%If you prefer comments, comment out above line

fprintf('Base case load flow:'); %base case load flow
tic
[results] = runpf(mpc, mpopt); %save it as a variable results
toc
mpc.gen(find(mpc.gen(:,1)==find(mpc.bus(:,2)==3)),2)=results.gen(find(mpc.gen(:,1)==find(mpc.bus(:,2)==3)),2); % to equate the slack bus with the initial output

% if the initial load flow is not successful give warning
while results.success ~=1
    if sum(mpc.bus(:,3))>0.1 %if there is load to shed (assuming the min. load is 0.1 p.u. to prevent infinite loop)
    warning('Base Case load flow is not converged. 1% Load shedding will be performed...') 
    mpc= load_shedding(mpc,0.01); 
    [results] = runpf(mpc, mpopt);
    else %there is no load to shed
    warning('There is no load to shed. Check base case data...') 
    results.success =1; %break the while loop
    end
end


%number of links
num_links=size(results.branch,1);
%Number of nodes
num_nodes=size(results.bus,1);

%set the capacity values of the links
%at the moment we assume that each link in the network has the same
%tolerance parameter.  C_i=F_i(1+alpha). Alpha needs to be inputted to the
%simulation.
alpha=1;

% Find the apperent power on each network link. Due to the losses over the
% link and the voltage difference between the from bus and to bus, the bus
% at the from node is not equal to the power at the to bus. Assume the flow
% S over the link is average value of those two.
% S=((P_from^2+Q_from^2)^0.5+(P_to^2+Q_to^2)^0.5)/2
S_branch =(sqrt((results.branch(:, PF)).^2+(results.branch(:, QF)).^2)+sqrt((results.branch(:, PT)).^2+(results.branch(:, QT)).^2))/2;

% C_i=F_i(1+alpha)
capMatrix = S_branch.*ones(size(results.branch,1),1)*(1+alpha);
%if there is a zero capacity, replace it with min non zero capacity
capMatrix(capMatrix==0)=min(capMatrix(capMatrix>0));

% change the capacity values smaller than 'thres'  with thres*(1+alpha) 
%if it is zero, you do not change anything

thres=mean(S_branch);
capMatrix(find(S_branch<thres))=thres*(1+alpha);

%encript capacity matrix data to one of the ratings in the branch data, lets say rate_A
mpc.branch(:,RATE_A)= capMatrix;
results.branch(:,RATE_A)= capMatrix;

%encript initial link number data to one of the ratings in the branch data,
%lets say rateB
mpc.branch(:,RATE_B)= 1:num_links;
results.branch(:,RATE_B)= 1:num_links;



lineThreat= (1:num_links)'; %Needs to be an input, column vector 
lineThreat=lineThreat(S_branch>thres); %here all links whose flow is more than the average the thres flow will be simulated

nodeThreat=[]; %Needs to be an input,



%initialisation for cascade...
results_base=results;
base_case=mpc; % just for future reference, save it as base case
link_vul=zeros(num_links,2);
link_vul(:,1)=1:num_links;

tic
for e=1:length(lineThreat) %for all links to be simulated
  
    mpc=base_case; %load the base case unchanged
    results=results_base; %load the base case results unchanged
   
    %Check the warning message regarding the attacks to see your link
    %threats are correct

 fprintf('Initial link attack(s)...\n');

fprintf('Attacked link %d: ', lineThreat(e,1));
fprintf('Between nodes %d and %d\n', [mpc.branch(lineThreat(e,:),T_BUS) ,mpc.branch(lineThreat(e,:),F_BUS)]);



%take the attacked links out of service
mpc.branch(lineThreat(e,1),BR_STATUS)=0;   

%calculate initial loadings before cascade
[S_branch, Branch_loading]= Calculate_S_links(results);
line_flow(e,1)=S_branch(lineThreat(e,1),2); %the flow of the failed  line before cascade

%find the effect of initial atack on the topology
[islands_current ,island_cont]= Update_case_data_v2(mpc, Branch_loading);
%islands_current: struct data containing the current stage islands
%islands_cont: 1 or 0 : 1 if islands cont to iterate; 0 if island is dead
    
%start cascading failures
stage=1;    
Branch_loading=cell(1);
Branch_loading{1,1}=100; %a dummy variable to store the loading of the branches in the islands of the current stage
islands_formed=cell(1,1); %will store the islands
links_removed=cell(1,1); %will store the removed links before the stage
links_removed{1,1}=[lineThreat(e,1); sort(unique([mpc.branch(ismember(mpc.branch(:,1),nodeThreat),RATE_B);mpc.branch(ismember(mpc.branch(:,2),nodeThreat),RATE_B)]))];


while sum(any(vertcat(Branch_loading{:})>=100))>0 
    %continue cascading failures till there is no overload
    
fprintf('Cascading Stage %d... \n', stage );     

islands_formed{stage,1}=islands_current;
islands_formed{stage,2}=island_cont;
%islands_formed os the variable containing the case datas for each islands
%in the first column, the continuity information of the islands in the
%second column

islands_inter=[]; %dummy variable to have the current continuing islands

for i=1:size(island_cont,2) %for all islands that is formed
    if island_cont(1,i)>0 %if island continues
        islands_inter=[islands_inter islands_current{1,i}];
    end
end

stage=stage+1; % iteration number next stage

results_inter=[]; %dummy variable for the intermediate cases results
index_to_clear=[];
for i=1:size(islands_inter,2) %for all islands, we will do load flow now
    
    results.success=0; % for every island till we have a convergence
    while results.success<1
    fprintf('Island %d \n', i );    
    results = runpf(islands_inter(1,i), mpopt);
    if results.success ~=1 %if it is not converged
        if sum(islands_inter(1,i).bus(:,3))>1 %if there is load to shed( it is bigger than 0 to prevent infinite loop)
    warning('The AC load flow is not converged. 5% Load shedding will be performed...') 
    islands_inter(1,i)= load_shedding(islands_inter(1,i),0.05);
        else%if there is no load to shed
            warning('There is no load left to shed. Island is dead...') 
            islands_formed{stage-1,2}(1,i)=0; %island is remarked as dead
            index_to_clear=[index_to_clear;i];
            results.success=1;
        end
    end
    end
    results_inter=[results_inter results ];
end
  islands_inter(index_to_clear)=[]; %clear that island from the current islands
  results_inter(index_to_clear)=[];
  
Branch_loading=[]; %dummies for the current stage
S_branch=[]; %dummies for the current stage

for i=1:size(islands_inter,2) %for all islands that continue
    
[S_branch_dum, Branch_loading_dum]= Calculate_S_links(results_inter(1,i));
Branch_loading=[Branch_loading {Branch_loading_dum}];
S_branch= [S_branch  {S_branch_dum}];
%find the branch loading and write them into cells
end

%prepare the next stage

islands_current=[];
island_cont=[];
links_removed{stage,1}=[];

for i=1:size(islands_inter,2) %for all islands that continue
     fprintf('Island %d \n', i );
    if any(Branch_loading{1,i}>=100)%meaning there is an overloaded link
        links_removed_dum=results_inter(1,i).branch((Branch_loading{1,i}>=100),RATE_B);
        links_removed{stage,1}=[links_removed{stage,1} ;links_removed_dum]; %store loaded links
        %find new islands
        [islands_current_dummy ,island_cont_dummy ]= Update_case_data_v2(results_inter(1,i), Branch_loading{1,i});   
        islands_current= [islands_current islands_current_dummy ];
        island_cont=[island_cont island_cont_dummy];
    else %meaning there is no overload in that island. For that one, cascading failures has stopped

      islands_current= [islands_current {islands_inter(1,i)}];  
      island_cont=[island_cont ,-1]; %no overload island do not need to iterate, but continues to live, mark it as -1
    end 
end


%convert vector to cell if branch loading is empty (otherwise it gives
%error)
if sum(size(Branch_loading))==0
Branch_loading={};
end


end

link_vul(cell2mat({links_removed{2:end,:}}'),2)=link_vul(cell2mat({links_removed{2:end,:}}'),2)+1;

rem_load=zeros(size(islands_formed,1),1);

for i=1:size(islands_formed,1)
  for j=1:size(islands_formed{i,1},2)
        if islands_formed{i,2}(1,j)~=0
        rem_load(i,1)=rem_load(i,1)+sum(islands_formed{i,1}{1,j}.bus(islands_formed{i,1}{1,j}.bus(:,2)<4,PD)); %these are updated to check outpuf service buses
        end
        if islands_formed{i,2}(1,j)==-1 %add the load of non iterating islands to the remaining load
        rem_load(i+1:end,1)=rem_load(i+1:end,1)+sum(islands_formed{i,1}{1,j}.bus(islands_formed{i,1}{1,j}.bus(:,2)<4,PD));
        end
  end
end


base_load=sum(base_case.bus(:,PD));

Yield(e,1)=rem_load(end)/base_load;


live_node=zeros(size(islands_formed,1),1);

for i=1:size(islands_formed,1)
  for j=1:size(islands_formed{i,1},2)
        if islands_formed{i,2}(1,j)~=0
        live_node(i,1)=live_node(i,1)+size(islands_formed{i,1}{1,j}.bus(islands_formed{i,1}{1,j}.bus(:,2)<4,1),1); %this is updated in order to eliminate outof service nodes
        end
        if islands_formed{i,2}(1,j)==-1 %add the load of non iterating islands to the remaining load
        live_node(i+1:end,1)=live_node(i+1:end,1)+size(islands_formed{i,1}{1,j}.bus(islands_formed{i,1}{1,j}.bus(:,2)<4,1),1);
        end
  end
end


loss_node(e,1)=(num_nodes-live_node(end))/num_nodes;

live_links=zeros(size(islands_formed,1),1);
for i=1:size(islands_formed,1)
  for j=1:size(islands_formed{i,1},2)
        if islands_formed{i,2}(1,j)~=0
        live_links(i,1)=live_links(i,1)+sum(islands_formed{i,1}{1,j}.branch(:,BR_STATUS)==1);
        end
        if islands_formed{i,2}(1,j)==-1 %add the load of non iterating islands to the remaining load
        live_links(i+1:end,1)=live_links(i+1:end,1)+sum(islands_formed{i,1}{1,j}.branch(:,BR_STATUS)==1);
        end
  end
end


loss_link(e,1)=(num_links-live_links(end))/num_links;

 


 
end
toc
%base case plot
% figure;
% [C,IA,IC] = unique(mpc.branch(:,1:2),'rows','stable');
% graph_base=graph(C(:,1),C(:,2));
% plot(graph_base, 'Layout','force')
% title('Base Case Graph');
