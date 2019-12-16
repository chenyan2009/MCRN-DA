clear; clc;
%To do:
%% Adjust Noise! Double check all


% 1) Make the observation times more general, typically is an integer multiple of the time step. DONE.
% 2) Add other models, e.g., Lorenz '96, ... DONE.
% 3) Implement Proj-PF with Proj-Resamp DONE.
% 4) Implement OP-PF (DONE.) and Proj-OP-PF
% 5) Implement other observation operators. DONE.
% 6) Implement separate covariances for IC and for resampling. DONE.

%% Initialization
% Compute time steps
t0 = 0;
endtime = 10;
h=5.E-3;
Numsteps = endtime/h;
timeSteps = linspace(t0,endtime,Numsteps); % timesteps
Fmod = @lorenz96;
%% Create Reduced Model
tol = 0.999; % Set POD tolerance
N = 400;  % dimension of the Lorenz96 system.
IC = zeros(N,1); %ICs for particles
IC(1)=1;

% Get information from full model
[~,w] = ode45(@lorenz96,timeSteps,IC);
lorenz96run = w';

[r, Xr, Ur, Vr, Sr] = orderReduction(tol, lorenz96run); % Get POD
Q = Ur;            % Let Q denote the first r columns of U

% Now that we have Q we can build G = Q^T F(QQ^T u) when needed
%% Initialize Parameters
%Use of projection (iproj=0 => No Projection, iproj=1 => Projection)
iproj=1;
%Use of standard PF or OP-PF (iOPPF=0 => standard PF, iOPPF=1 => OP-PF)
iOPPF=1;
%Number of particles
L=50;
%alpha value for projected resampling
alpha=1.0;

%Multiple of the step size for observation time
ObsMult=10;
%Rank of projection, number of Lyapunov exponents for AUS projection
p=10;


%% Set Covariance Matricies
%For diagonal (alpha*I) covariance matrices.
%Observation
epsR = 0.01;
%Model
epsSig = 0.01;
%Resampling
epsOmega = 2.E-3;
%Initial condition
epsIC = 0.1;

%Observe every inth variable.
inth=2;

%% Call Initialize function and initialize particles
%Call Init
[M,H,PinvH,IC,q,LE,w,R,Rinv,Sig,Omega,ICcov,Lones,Mzeros,Nzeros] = Init(Fmod,IC,h,N,inth,Numsteps,p,L,epsR,epsSig,epsOmega,epsIC);
Rinvfixed=Rinv;

%Add noise N(0,ICcov) to ICs to form different particles
x = repmat(IC,1,L) + mvnrnd(Nzeros,ICcov,L)'; %ICchol*randn(N,L);
x = Q' * x;
estimate(:,1) = x*w;

y=zeros(M,Numsteps);


%% Generate observations from "Truth"
for i = 1:Numsteps ;
    t = timeSteps(i);
    truth(:,i) = IC;
    if mod(i,ObsMult)==0
        y(:,i)=H*IC + mvnrnd(Mzeros,R,1)'; %Rchol*rand(M,1); % + Noise from N(0,R)
    end
    IC = dp4(Fmod,t,IC,h);
end



% Initialize error values
Resamps=0;
RMSEave=0;
iRMSE=1;


%% Run main part of filter
%Loop over observation times
for i=1:Numsteps;
    t = timeSteps(i);
    %Form AUS projection and update LEs
    est=estimate(:,i);
    [q,LE] = getausproj(N,p,Fmod,t,est,h,q,LE);
    
    if mod(i,ObsMult)==0
        %At observation times, Update weights via likelihood
        
        if (iOPPF==0)
            %Add noise only at observation times
            x = x + mvnrnd(Nzeros,Sig,L)';
            %Standard Particle Filter
            if (iproj==0)
                %Standard PF (no projection)
                Innov = repmat(y(:,i),1,L) - H*x;
            else
                %Proj-PF
                %H -> Q_n^T P_H where P_H = H^T (H H^T)^{-1} H = H^+ H
                %R -> Q_n^T H^+ R (H^+)^T Q_n where H^+ = H^T (H H^T)^{-1}
                Innov = q'*PinvH*(repmat(y(:,i),1,L) - H*x);
                Rinv = pinv(q'*PinvH*R*PinvH'*q);
            end
            
        else %IOPPF==1
            if (iproj==0)
                Qpinv = inv(Sig) + H'*Rinvfixed*H;
                Qp = inv(Qpinv);
                %Optimal proposal PF
                Innov = repmat(y(:,i),1,L) - H*x;
                x = x + Qp*H'*Rinv*Innov + mvnrnd(Nzeros,Qp,L)';
                Rinv = inv(R + H*Sig*H');
            else
                %Proj-OP-PF
                %H -> Q_n^T P_H where P_H = H^T (H H^T)^{-1} H = H^+ H
                %R -> Q_n^T H^+ R (H^+)^T Q_n where H^+ = H^T (H H^T)^{-1}
                Qpinv = inv(Sig) + H'*Rinvfixed*H;
                Qp = inv(Qpinv);
                Innov = repmat(y(:,i),1,L) - H*x;
                x = x + Qp*H'*Rinvfixed*Innov + mvnrnd(Nzeros,Qp,L)';
                Innov = q'*PinvH*Innov;
                %UPDATE: H and R in Qpinv
                %Rnew = q'*PinvH*R*PinvH'*q;
                %Qpinv = inv(Sig) + PinvH*H*q*inv(Rnew)*q'*PinvH*H;
                %Qp = inv(Qpinv);
                Rinv = pinv(q'*PinvH*(R+H*Sig*H')*PinvH'*q);
                
            end
        end
        
        Tdiag = diag(Innov'*Rinv*Innov);
        tempering = 1.2; %%%% <<< including new parameter here for visibility. Tempering usually a little larger than 1.
        Tdiag = (Tdiag-max(Tdiag))/tempering; %%%%% <<<< Think dividing the exponent is dangerous; this was tempering with an unknown coefficient.
        LH = exp(-Tdiag/2); %%%% <<<< divided exponent by 2; this is part of the normal distribution
        w=LH.*w;
        
        %Normalize weights
        w=w/(w'*Lones);
        
        %Resampling (with resamp.m that I provided or using the pseudo code in Peter Jan ,... paper)
        [w,x,NRS] = resamp(w,x,0.5);
        Resamps = Resamps + NRS;
        
        %Update Particles
        %Note: This can be modified to implement the projected resampling as part of implementation of PROJ-PF:
        %Replace Sigchol*randn(N,L) with (alpha*Q_n*Q_n^T + (1-alpha)I)*Sigchol*randn(N,L)
        if (NRS==1)
            if (iproj==0)
                %Standard resampling
                x = x + mvnrnd(Nzeros,Sig,L)'; %Sigchol*randn(N,L);
            else
                %Projected resampling
                x = x + (alpha*q*q' + (1-alpha))*mvnrnd(Nzeros,Omega,L)'; %Omegachol*randn(N,L);
            end
        end
        
        %END: At Observation times
    end
    
    %Predict, add noise at observation times
    x = dp4(Fmod,t,x,h);
    
    estimate(:,i+1) = x*w;
    
    diff = truth(:,i)-estimate(:,i);
    RMSE = sqrt(diff'*diff/N);
    RMSEave = RMSEave + RMSE;
    
    if mod(i,ObsMult)==0
        %Save RMSE values
        Time(iRMSE)=t;
        RMSEsave(iRMSE)=RMSE;
        iRMSE = iRMSE+1;
        
%         %Plot
%         yvars=colon(1,inth,N);
%         vars = linspace(1,N,N);
%         sz=zeros(N,1);
%         plots(1) = plot(vars,truth(:,i),'ro-');
%         hold on
%         plots(2) = plot(vars,estimate(:,i+1),'bo-');
%         
%         for j=1:L
%             sz(:)=w(j)*80*L;
%             scatter(vars,x(:,j),sz,'b','filled');
%             
%         end
%         plots(3) = plot(yvars,y(:,i),'g*','MarkerSize',20);
%         title(['Time = ',num2str(t)])
%         legend(plots(1:3),'Truth','Estimate','Obs');
%         pause(1);
%         hold off
        
    end
    
    
    
end


% RMSEave = RMSEave/Numsteps
% ResampPercent = ObsMult*Resamps/Numsteps
% LE = LE/(t-t0)
%% Plot our estimates against the background model the 
truth = Q*truth;
estimate = Q* estimate;
plot(timeSteps,lorenz96run(1,:),'color','green')
hold on;
plot(timeSteps,truth(1,:),'color','blue')
hold on;
plot(timeSteps,estimate(1,1:(end - 1)),'color','red')
legend({'Full Lorenz Model','True values','PF Estimated Values'},'location','southeast')
