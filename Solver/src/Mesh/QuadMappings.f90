         function Edge_AnalyticalX( self , xi , direction ) result( p )
            implicit none
            class(Edge_t), intent(in)           :: self
            real(kind=RP), intent(in)           :: xi
            integer      , intent(in)           :: direction
            real(kind=RP)                       :: p(2)
!           ------------------------------------------------------------
            real(kind=RP)                       :: correctedXi
            
            if (direction .eq. BACKWARD) then
              correctedXi = 1.0_RP - xi
            elseif (direction .eq. FORWARD) then
              correctedXi = xi
            end if 

            p = self % nodes(1) % n % X * (1.0_RP - correctedXi) + self % nodes(2) % n % X * correctedXi

         end function Edge_AnalyticalX

         function Curvilinear_InterpolantX( self , xi , direction ) result( p )
            use MatrixOperations
            implicit none
            class(CurvedBdryEdge_t), intent (in) :: self
            real(kind=RP),           intent (in) :: xi
            integer      ,           intent (in) :: direction
            real(kind=RP)                        :: p(2)
!           ------------------------------------------------------------
            real(kind=RP), allocatable           :: auxp(:,:)
            real(kind=RP)                        :: correctedXi
            real(kind=RP), allocatable           :: lj(:,:)
            
            if (direction .eq. BACKWARD) then
              correctedXi = 1.0_RP - xi
            elseif (direction .eq. FORWARD) then
              correctedXi = xi
            end if 

            allocate(lj( 0 : self % spA % N , 1 ) )
            allocate(auxp(NDIM , 1) )
            lj(:,1) = self % spA % lj(correctedXi)

            auxp(1:NDIM,1:) = MatrixMultiply_F( self % X , lj )

            p = auxp(1:NDIM,1)
            
            deallocate(lj , auxp)

         end function Curvilinear_InterpolantX

         function Edge_AnalyticaldS( self , xi , direction ) result( dS )
            implicit none
            class(Edge_t), intent(in)        :: self
            real(kind=RP), intent(in)        :: xi
            integer,       intent(in)        :: direction
            real(kind=RP)                    :: dS(2)
!           --------------------------------------------------------------

            associate( n1 => self % nodes(1) % n % X , &
                       n2 => self % nodes(2) % n % X )

               dS(1) = n2(2) - n1(2)
               dS(2) = -(n2(1) - n1(1))

            end associate

         end function Edge_AnalyticaldS

         function Curvilinear_InterpolantdS( self , xi , direction ) result( dS )
            use MatrixOperations
            implicit none
            class(CurvedBdryEdge_t), intent(in)        :: self
            real(kind=RP), intent(in)        :: xi
            integer,       intent(in)        :: direction
            real(kind=RP)                    :: dS(2)
!           --------------------------------------------------------------
            real(kind=RP), allocatable           :: dP(:,:)
            real(kind=RP), allocatable           :: auxdS(:,:)
            real(kind=RP), allocatable           :: lj(:,:)
            real(kind=RP)                        :: correctedXi
            
            if (direction .eq. BACKWARD) then
              correctedXi = 1.0_RP - xi
            elseif (direction .eq. FORWARD) then
              correctedXi = xi
            end if 

            allocate(dP(NDIM , 0 : self % spA % N) )
            allocate(lj(0 : self % spA % N , 1 ) )
            allocate(auxdS(NDIM , 1) )

            lj(:,1) = self % spA % lj(correctedXi)

            associate ( D => self % spA % D )
            
               dP = NormalMat_x_TransposeMat_F( self % X , D )
               auxdS(1:NDIM,1:) = MatrixMultiply_F( dP , lj ) 
            
            end associate

            dS(1) = -auxdS(2 , 1)
            dS(2) = auxdS(1,1)
         
            deallocate( lj , dP , auxdS )

         end function Curvilinear_InterpolantdS

         subroutine QuadElement_SetMappings ( self ) 
            use MatrixOperations
            implicit none
            class(QuadElement_t)          :: self 
            integer                       :: ixi , ieta
!
!           **************************************
!           Set the mapping for the inner points X
!              Also, compute dX, the derivatives
!           **************************************
!
            associate ( N => self % spA % N , xi => self % spA % xi , eta => self % spA % xi , &
                        gBOT => self % edges(EBOTTOM) % f , & 
                        gTOP => self % edges(ETOP) % f  , & 
                        gLEFT => self % edges(ELEFT) % f , & 
                        gRIGHT => self % edges(ERIGHT) % f , & 
                        dBOT => self % edgesDirection(EBOTTOM) , &
                        dTOP => self % edgesDirection(ETOP) , & 
                        dLEFT => self % edgesDirection(ELEFT) , & 
                        dRIGHT => self % edgesDirection(ERIGHT) , & 
                        n1 => self % nodes(1) % n % X , n2 => self % nodes(2) % n % X , n3 => self % nodes(3) % n % X , n4 => self % nodes(4) % n % X ) 

               do ixi = 0 , N
                  do ieta = 0 , N 
                     
                     self % x(iX:iY, ixi , ieta) =  (1.0_RP - eta(iEta)) * gBOT % getX(iXi,dBOT) + xi(iXi)*gRIGHT % getX(iEta,dRIGHT) + &
                                                    (1.0_RP - xi(iXi) )  * gLEFT % getX(N-iEta,dLEFT) + eta(iEta)*gTOP % getX(N-iXi,dTOP)  &
                                                    -n1*(1.0_RP - xi(iXi))*(1.0_RP - eta(iEta)) - n2 * xi(iXi) * (1.0_RP - eta(iEta)) & 
                                                    -n3* xi(iXi) * eta(iEta) - n4 * (1.0_RP - xi(iXi)) * eta(iEta)
                  end do
               end do

            end associate

            self % dx(:,:,:,iX) = MatrixMultiplyInIndex_F( self % x , transpose(self % spA % D) , 2)
            self % dx(:,:,:,iY) = MatrixMultiplyInIndex_F( self % x , transpose(self % spA % D) , 3)

         end subroutine QuadElement_SetMappings

         function Edge_getX( self , iXi , direction ) result ( X ) 
            implicit none
            class(Edge_t), intent(in)                 :: self
            integer      , intent(in)                 :: iXi
            integer      , intent(in)                 :: direction
            real(kind=RP)                             :: X (NDIM)
!           -------------------------------------------------------------
            integer                                   :: correctediXi

            if (direction .eq. FORWARD) then
               correctediXi = iXi
            
            elseif (direction .eq. BACKWARD) then
               correctediXi = self % spA % N - iXi
      
            end if

            X = self % X(iX:iY,correctediXi)

         end function Edge_getX

         function Edge_getdX( self , iXi , direction ) result ( dX ) 
            implicit none
            class(Edge_t), intent(in)                 :: self
            integer      , intent(in)                 :: iXi
            integer      , intent(in)                 :: direction
            real(kind=RP)                             :: dX (NDIM)
!           -------------------------------------------------------------
            integer                                   :: correctediXi
            real(kind=RP)                             :: newsign

            if (direction .eq. FORWARD) then
               correctediXi = iXi
               newsign = 1.0_RP
            
            elseif (direction .eq. BACKWARD) then
               correctediXi = self % spA % N - iXi
               newsign = -1.0_RP
      
            end if

            dX = newsign * self % dX(iX:iY,correctediXi)

         end function Edge_getdX