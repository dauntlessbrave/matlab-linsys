classdef dataFit
%This is just a collection of a model, a dataset, and a state estimate to implement some useful functions
properties (SetAccess = immutable)
  model
  dataSet
  stateEstim
  initialCondition=initCond([],[]);
  fitMethod='KS';
  logL
  %reducedGoodnessOfFit
end

properties (Dependent)
  output
  oneAheadOutput
  residual
  oneAheadResidual
  deterministicResidual
  goodnessOfFit %Metric to quantify the fit, can be logL, RMSE depending on how data was fit
  stateNoise %This can only be meaningfully estimated if the fitting method is KS
  obsNoise %Not sure, but this makes the most sense to estimate when method is KS too
end
methods
  function this=dataFit(model,datSet,fitMethod,initC)
      if nargin<4 || isempty(initC)
        initC=initCond([],[]);
        %D1=size(model.A,1);
        %initC=initCond(zeros(D1,1), 1e5*eye(D1));
      end
      if nargin<3 || isempty(fitMethod)
        fitMethod='KS';
      end
      [MLE,filtered,oneAhead,rej,logL]=model.Ksmooth(datSet,initC);
      switch fitMethod
        case 'KF' %Kalman filter
          this.stateEstim=filtered;
        case 'KS' %Kalman smoother
          this.stateEstim=MLE;
        case 'KP' %Kalman one-ahead predictor
          this.stateEstim=oneAhead;
      end
      this.model=model;
      this.dataSet=datSet;
      this.fitMethod=fitMethod;
      this.logL=logL;
      %Compute reduced log-l: (that is, ignoring portion of the output
      %outside of the span of C)
      %[redSys,redDatSet]=model.reduce(datSet);
      %[~,~,~,~,redLogL]=redSys.Ksmooth(redDatSet,initC);
      %this.reducedGoodnessOfFit=redLogL;
  end
  function res=get.residual(this)
      res=this.output - this.dataSet.out;
  end
  function res=get.oneAheadResidual(this)
      res=this.oneAheadOutput - this.dataSet.out;
  end
  function res=NaheadResidual(this,N)
      res=this.NaheadOutput(N)-this.dataSet.out;
  end
  function out=get.output(this)
      N=size(this.dataSet.out,2);
      out=this.model.C*this.stateEstim.state(:,1:N)+this.model.D*this.dataSet.in;
  end
  function out=get.oneAheadOutput(this)
      out=this.NaheadOutput(1);
      return;
      %Old version:
      if strcmp(this.fitMethod,'KS')
          error('dataFit:oneAheadOutputNotPredictive','Requesting one-ahead output for smoothed states. This makes no sense (because smoothing uses future data to fit!).')
      end
      N=size(this.dataSet.out,2);
      iC=this.initialCondition.state;
      if isempty(iC)
          iC=nan(size(this.model.A,1),1);
      end
      predictedState=[iC this.model.A*this.stateEstim.state(:,1:N-1)+this.model.B*this.dataSet.in(:,1:N-1)];
      relevantInput=[zeros(size(this.dataSet.in,1),1) this.dataSet.in(:,1:N-1)];
      out=this.model.C*predictedState+this.model.D*relevantInput;
  end
  function out=NaheadOutput(this,M)
      %Output predicted from state MLE M steps ahead
      if strcmp(this.fitMethod,'KS')
          error('dataFit:oneAheadOutputNotPredictive','Requesting M-ahead output for smoothed states. This makes no sense (because smoothing uses future data to fit!).')
      end
      N=size(this.dataSet.out,2);
      MaheadState=[nan(this.model.order,M) this.stateEstim.state(:,1:N-M)];
      st=stateEstimate(MaheadState,zeros(this.model.order,this.model.order,N));
      pSt=this.model.predict2(st,[nan(size(this.dataSet.in,1),M) this.dataSet.in],M); %Predictin M samples into the future
      out=this.model.C*pSt.state+this.model.D*this.dataSet.in;
  end
  function res=get.deterministicResidual(this)
      %This function is here for convenience, as this does not depend on
      %the fit
      [datSet,~]=this.model.simulate(this.dataSet.in,this.initialCondition,true,true);
      res=datSet.out - this.dataSet.out;
  end
  function gof=get.goodnessOfFit(this)
     switch this.fitMethod 
         case 'KF' 
             gof=this.logL;
         case 'KS' 
             gof=this.logL;
         case 'LS'
             gof=sqrt(nanmean(nansum(this.residual.^2,1)));
         otherwise
             error('Unimplemented')
     end
  end
  function on=get.obsNoise(this)
       if ~strcmp(this.fitMethod,'KS')
           error('Observation noise estimation is only defined for KS fitted models')
       end
     on=this.residual;
  end
  function sn=get.stateNoise(this)
       if ~strcmp(this.fitMethod,'KS')
           error('State noise estimation is only defined for KS fitted models')
       end
       N=size(this.dataSet.out,2);
     sn=this.stateEstim.state(:,2:N)-this.model.A*this.stateEstim.state(:,1:N-1) - this.model.B*this.dataSet.in(:,1:N-1);
  end
end

end
