function [S_branch, Branch_loading]= Calculate_S_links(results)


%input a result of a load flow

define_constants; %define constants for matpower 
S_branch(:,1)=results.branch(:,7);
S_branch(:,2)=((sqrt((results.branch(:, PF)).^2+(results.branch(:, QF)).^2)+sqrt((results.branch(:, PT)).^2+(results.branch(:, QT)).^2))/2);
%the apparent power flow over a link
%Branch_loading(:,1)=results.branch(:,7);
%Branch_loading(:,2) =S_branch(:,2)./ results.branch(:,RATE_A) *100; %make
%branch numbers appear
Branch_loading(:,1) =S_branch(:,2)./ results.branch(:,RATE_A) *100;
%the percentage of the initial loading
end