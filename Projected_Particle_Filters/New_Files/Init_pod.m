function [M,H,PinvH,IC,q,w,R,Rinv,Sig,Omega,ICcov,Lones,Mzeros,Nzeros] = Init_pod(Fmod,IC,h,N,inth,Numsteps,p,L,epsR,epsSig,epsOmega,epsIC,Ur)

%Linear Observation operator, every inth variable
Heye=eye(N,N);
H=Heye(1:inth:end,:);
%M = Dimension of observation space.
[M,~]=size(H)
%yvars=linspace(1,M,M);
PinvH=pinv(H);

%Init for LEs and projections
q=orth(randn(N,p));
% LE=zeros(p,1);

%Spin up
t=0;
for i = 1:Numsteps*2
t = t+h;
[q] = getpod(Ur,p);
% [q,LE] = getausproj(N,p,Fmod,t,IC,h,q,LE);
IC = dp4(Fmod,t,IC,h);
end

% LE=zeros(p,1);

%Init for Weights
w = zeros(L,1);
w(:)=1/L;

%Init for covariance matrices
%R as the observation error covariance
R = epsR*eye(M);
Rinv = inv(R);

%Sig as model error covariance
Sig = epsSig*eye(N);

%Omega covariance for Resampling
Omega = epsOmega*eye(N);

%IC covariance
ICcov = epsIC*eye(N);

Lones = ones(L,1);
Mzeros=zeros(M,1);
Nzeros=zeros(N,1);
