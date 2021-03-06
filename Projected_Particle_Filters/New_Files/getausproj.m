function [q,LE] = getausproj(N,p,Fmod,t,est,h,q,LE)

%%%% BEGIN: FORM AUS PROJECTION
NEWDIFF=zeros(N,p);
sqrteps=sqrt(eps(1));

% OVER ALL THE LYAPUNOV EXPONENTS WE WANT, SOME p<=DIM
   xnew = dp4(Fmod,t,est,h);

%EVALUATE F(X+eps^{1/2}*Qj)
   NEWIC = repmat(est,1,p)+sqrteps*q;
   QTAU = dp4(Fmod,t,NEWIC,h);
   NEWDIFF = (QTAU - repmat(xnew,1,p))/sqrteps;

%CALL mgs
   [q,r] = mgs(NEWDIFF);

%FORM LES
   LE = LE + log(diag(r));
%%%% END: FORM AUS PROJECTION
