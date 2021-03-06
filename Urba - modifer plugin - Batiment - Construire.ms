



----------- Construction des batiments----------------------------------------------------------------------
struct str_construire (
	
		------------ DEBUG	-------------------------------------------------------------------------------------------------------------------------
		m_debug = true,
		m_dbgPrefix ="urba | str_construire",
		fn debug 	_txt  var:	 param:    =(
			try if m_debug do ::debuger 	_txt  	var:var	 param:param	prefix:m_dbgPrefix
			catch ()
		),
		fn logout 	_txt  var:	 param:    =(
			::ecrire 	_txt  	var:var	 param:param	prefix:m_dbgPrefix	script:"URBA"
			
		),
		
		
		
		---- Membres ---------------------------------------------
	public
		m_geo,		
		m_this,
		
	private
		m_outils					=	str_constr_outils (),
		m_matID				= str_prefs_matID (),
		modeles_import 		=#(),		
		
		---- constantes------------------
	private
		ep_ssBassement 	= 	100,
		ep_dalle 			= 20,
		ep_mur	 			= 20,
		ep_couvertine	 	= 5,
		
		
		
		---- Fonctions ---------------------------------------------
	private
	
		------------ FILTRES-------------------------
		fn filtrer_facades_parEtages   	_facades 		_etageCourant	 =(
			
			local facades_result =#()
			
			--- on filtre par etages ---------------
			for fcade in _facades 		do (					
				if fcade.etages_use_min then (
					if _etageCourant	>= fcade.etages_nbre_min  do (
						if fcade.etages_use_max then (
							if _etageCourant <= fcade.etages_nbre_max   do 	
								append facades_result fcade
						)	else (
							append facades_result fcade
						)
					)
				) else (
					append facades_result fcade
				)
			)
			
-- 			debug "...............................filtrer_facades_parEtages" 
-- 			debug "...............................facades_result" var:facades_result
			facades_result
		),
		fn filtrer_facades_parMurs		_facades	_mur_longueur		_id_pt				=(
			
			local facades_result 		= #()			
			local est_pignon				= m_this.trace.est_pignon		_id_pt
			
			---- si la sequence peut rentrer sur le segment de facade ------------
			for fcde in _facades where fcde.sequence_longueur != 0 and fcde.sequence_longueur < _mur_longueur do (
				---- si la facade est limit� en longueur min -----
				if not fcde.longueur_use_min or fcde.longueur_use_min	 and 	fcde.longueur_nbre_min < _mur_longueur do
					---- si la facade est limit� en longueur max -----
					if not fcde.longueur_use_max or fcde.longueur_use_max	 and 	fcde.longueur_nbre_max > _mur_longueur do (
						---- si la facade est sur le bon type de mur -----
						case  fcde.murs of (
							1: append facades_result fcde
							2: if not est_pignon do append facades_result fcde
							3: if est_pignon do append facades_result fcde
						)
					)
			)
	
			facades_result
			
		),
		fn choisir_parProbas		_liste	 = (
			local result 	
			
			local probaTotal = 0
			for elem in _liste do 
				probaTotal += elem.probabilite
			local tirage = random  1.  probaTotal
			local trouve = false
			local id = 1
			local probacourant = 0
			if _liste.count > 0 do (
				while not trouve and probacourant <= probaTotal	do (
					probacourant += _liste[id].probabilite
					if tirage < probacourant do (
						trouve = true
						result = _liste[id]
					)
					id += 1
				)
			)
			result
		),
		
		
		------------ TOITURES-------------------------		
	private
		fn toitPentes 				&z	_nbrePentes	=(
			
			local	 mtrx_axeP	=	m_this.axeP_mtrx
			local	 BB_axeP	=	m_this.axeP_BB
			translate mtrx_axeP	BB_axeP[1]
			
			local diag_axeP	=	(BB_axeP[2] * inverse mtrx_axeP) - (BB_axeP[1]  * inverse mtrx_axeP)
			local largeur 		=	diag_axeP.x
			local longeur 		= 	diag_axeP.z
			local hauteur 		= largeur * tan m_this.toit_pente		--	largeur /2 --* random .3 1.5
			
			local nvlsFaces 	= #()
			case _nbrePentes of (
				1: ( ---------- 1 PENTE ----------------------------------------------------------------------------------------------------
						--- gestion de l'angle de la pente .... ----
	-- 						hauteur = hauteur/4
						
						local pt_0 = (  [0,0,0]  *  mtrx_axeP )
						local pt_1 = (  [0,0,longeur]  *  mtrx_axeP )
						local pt_2 = (  [largeur ,hauteur,0]  *  mtrx_axeP )
						
						local vec1 = pt_1 - pt_0
						local vec2 = pt_2 - pt_0
						
						local pt_Origine = pt_0
						pt_Origine.z =  z + m_this.toit_hauteur
	-- 						point pos:pt_Origine	 isSelected:true
					
						local plan_pente = str_plan ()
						plan_pente.creerFrom_2vecs_et_1Point	vec1	vec2		pt_Origine
						
						local pointsPente = #()
						local pointsMurs   =#()
						for i = 1 to  m_this.trace_courant.count do (
							
							local j = i+1
							if j >  m_this.trace_courant.count  do j = 1
							
							--- point Mur ----
							local pt 			= 	m_this.trace_courant[i]	
							pt.z = z
							append pointsMurs  pt		
							
							local pt_result = plan_pente.projeter_point_verticalement 	pt
	-- 						pt_result.z += m_this.toit_hauteur
							append pointsPente  pt_result
							
						)
						
						--- creation de la face du dessus ----
						local faceDessus =  m_geo.pointsEtFaces 	pointsPente 	
						append nvlsFaces faceDessus
						
						-- m_matID --
						polyop.setFaceMatID m_this.delegate  #(faceDessus) 	m_matID.toiture
						
						---- creation des raccord mur ----------
						local facesMurs = #()
						for i = 1 to pointsMurs.count  do (
							
							local j = i+1
							if j >  pointsMurs.count  do j = 1
							
							local ptMur1 		= pointsMurs[i]
							local ptMur2 		= pointsMurs[j]
							local ptPente3 	= pointsPente[j]
							local ptPente4	= pointsPente[i]
							
							local pointsRaccord = #(ptMur1, ptMur2, ptPente3, ptPente4)
							local faceMurs = m_geo.pointsEtFaces 	pointsRaccord 	
							append nvlsFaces faceMurs
							polyop.setFaceMatID m_this.delegate  #(faceMurs) 	m_matID.mur
						)
					
						
						
						-- souder les points --
						local vertsASouder =#()
						for IDFace in nvlsFaces do (
							local vertsFace = polyop.getFaceVerts m_this.delegate	 IDFace
							for vert in vertsFace do 
								appendIfUnique  vertsASouder 	vert
							-- m_this.delegate.weldThreshold
						)
						polyop.weldVertsByThreshold m_this.delegate 		(vertsASouder as bitArray)
						
						
						---- debord et epaisseur du toit -----
						polyop.bevelFaces 	m_this.delegate  	faceDessus 	0.0 	30.
						polyop.extrudeFaces m_this.delegate  	faceDessus 	20.
						
						
-- 						format ".extrustionType : %\n" m_this.delegate.extrustionType
-- 						polyop.extrudeFaces m_this.delegate  	nvlsFaces 	0.0
-- 						polyop.extrudeFaces m_this.delegate  	nvlsFaces 	0.0
						
						
				)
				2: (---------- 2 PENTES ----------------------------------------------------------------------------------------------------
					
					
						--- Plan de la Pente 1  ----
						local pt_P1_0 = (  [0,0,0]  *  mtrx_axeP )
						local pt_P1_1 = (  [0,0,longeur]  *  mtrx_axeP )
						local pt_P1_2 = (  [largeur ,hauteur,0]  *  mtrx_axeP )	
					
						local vecP1_1 = pt_P1_1 - pt_P1_0
						local vecP1_2 = pt_P1_2 - pt_P1_0
						
						local pt_Origine = pt_P1_0
						pt_Origine.z =  z + m_this.toit_hauteur
						local plan_pente1 = str_plan ()
						plan_pente1.creerFrom_2vecs_et_1Point	vecP1_1		vecP1_2		pt_Origine
					
					
					
						--- Plan de la Pente 1  ----
						local pt_P2_0 = (  [largeur,0,longeur]  *  mtrx_axeP )
						local pt_P2_1 = (  [largeur,0,0]  *  mtrx_axeP )
						local pt_P2_2 = (  [0 ,hauteur,longeur]  *  mtrx_axeP )			
					
						local vecP2_1 = pt_P2_1 - pt_P2_0
						local vecP2_2 = pt_P2_2 - pt_P2_0
						
						local pt_Origine = pt_P2_0
						pt_Origine.z =  z + m_this.toit_hauteur
						local plan_pente2 = str_plan ()
						plan_pente2.creerFrom_2vecs_et_1Point	vecP2_1		vecP2_2		pt_Origine
					
						--- Plan verticale faitage ------
						local pt_F_0 = (  [largeur /2 ,0,0]  *  mtrx_axeP )
						local pt_F_1 = (  [largeur /2 ,0,longeur]  *  mtrx_axeP )
						local pt_F_2	=	pt_F_0 + [0,0,100]				
						
						local vec_F_1 = pt_F_1 - pt_F_0
						local vec_F_2 = pt_F_2 - pt_F_0				
						
						local pt_Origine = pt_F_0
						pt_Origine.z =  z 
						
						local plan_verticaleFaitage = str_plan ()
						plan_verticaleFaitage.creerFrom_2vecs_et_1Point	vec_F_1		vec_F_2		pt_Origine
						
						
						
						---- creation des liste des points-----------
						local pointsPente = #()
						local pointsPente1 = #()
						local pointsPente2 = #()
						local pointsMurs   =#()
						for i = 1 to  m_this.trace_courant.count do (
							
							local j = i+1
							if j >  m_this.trace_courant.count  do j = 1
							
							
							--- point Mur ----
							local pt 			= 	m_this.trace_courant[i]	
							pt.z = z
							append pointsMurs  pt		
							
							--- point pente ----
							local pt_pente1 = plan_pente1.projeter_point_verticalement 	pt
							local pt_pente2 = plan_pente2.projeter_point_verticalement 	pt
							if pt_pente1.z < pt_pente2.z then (
								append pointsPente  	pt_pente1
								append pointsPente1 	pt_pente1
								
							) else  (
								append pointsPente  	pt_pente2
								append pointsPente2  	pt_pente2
							)
							
							--- point mur - faitage ----
							local pt_suivant 	= 	m_this.trace_courant[j]	
							pt_suivant.z = z
							local intersect = plan_verticaleFaitage.coupe_segment	pt 	pt_suivant							
							if intersect do (
								local pt_faitage_mur = plan_verticaleFaitage.get_intersection_segment 	pt 	pt_suivant
								append pointsMurs  	pt_faitage_mur
								local pt_faitage_pente = plan_pente1.projeter_point_verticalement 	pt_faitage_mur
								append pointsPente  pt_faitage_pente
								
								
								append pointsPente1 	pt_faitage_pente
								append pointsPente2 	pt_faitage_pente
							)
							
							
							
						)
						
						
						
						
						--------- creation des geometries ---------------------
						--- les murs ----
						for i = 1 to pointsMurs.count  do (
							
							local j = i+1
							if j > pointsMurs.count do j = 1
							
							local ptMur1 		= pointsMurs[ i ]
							local ptMur2 		= pointsMurs[ j ]
							local ptPente3 	= pointsPente[ j ]
							local ptPente4	= pointsPente[ i ]
							
							local pointsRaccord = #(ptMur1, ptMur2, ptPente3, ptPente4)
							local nvlFace = m_geo.pointsEtFaces 	pointsRaccord 	
							append nvlsFaces nvlFace
							-- m_matID --
							polyop.setFaceMatID m_this.delegate  nvlFace 	m_matID.mur
						) 
						
						
						--- les pentes -----
						local facesDessus =#()
						local face1 =  m_geo.pointsEtFaces 		pointsPente1 	
						local face2 =  m_geo.pointsEtFaces 		pointsPente2 	
						
						append facesDessus face1
						append facesDessus face2
						
						append nvlsFaces face1
						append nvlsFaces face2
						
						
						-- m_matID --
						polyop.setFaceMatID m_this.delegate  facesDessus 	m_matID.toiture
						
						
						
						
						
						-- souder les points --
						local vertsASouder =#()
						for IDFace in nvlsFaces do (
							local vertsFace = polyop.getFaceVerts m_this.delegate	 IDFace
							for vert in vertsFace do 
								appendIfUnique  vertsASouder 	vert
							-- m_this.delegate.weldThreshold
						)
						polyop.weldVertsByThreshold m_this.delegate 		(vertsASouder as bitArray)
						
						facesDessus = #( m_this.delegate.getNumFaces () - 1, m_this.delegate.getNumFaces () )
						---- debord et epaisseur du toit -----
						polyop.bevelFaces 		m_this.delegate  	facesDessus 	0.0 	30.
						polyop.extrudeFaces 	m_this.delegate  	facesDessus 	20.
				)
			)
		),		
		fn acrotere					_face		= (
			
			---- les murs -----
			-- m_matID --
			polyop.setFaceMatID m_this.delegate  #(_face) 	m_matID.mur
			-- gemoetrie --			
			polyop.bevelFaces m_this.delegate 	#(_face) 	0 	-ep_mur
			local faceAExtruder = #{_face+1..(polyop.getNumFaces m_this.delegate)} as array
			polyop.extrudeFaces  m_this.delegate 	faceAExtruder 	m_this.toit_hauteur
			
			
			---- la couvertine  -----
			-- m_matID --
			polyop.setFaceMatID m_this.delegate  faceAExtruder 	m_matID.metal
			-- gemoetrie --
			polyop.bevelFaces m_this.delegate 	faceAExtruder		0 	ep_couvertine
			polyop.extrudeFaces m_this.delegate 	faceAExtruder		ep_couvertine
			
			local faceToitsSurface = m_outils.etendreFaces  	m_this.delegate 	#(_face)
			
			format "faceToitsSurface : %\n" faceToitsSurface
			
			
			-- m_matID --
			polyop.setFaceMatID m_this.delegate  faceToitsSurface 	m_matID.toiture
			
		),		
		fn toit 						&z =(
			case m_this.toit_type of (
				1: (	---- PLAT	----
					local trace_courant = for pt in m_this.trace_courant collect [pt.x,pt.y,z]
					m_geo.pointsEtFaces		trace_courant		  	m_matID:m_matID.toiture
				)
				2: (	---- ACROTERE	----
					
					
					--- creation de la facette globale-----
					local trace_courant 	= for pt in m_this.trace_courant collect [pt.x,pt.y,z]
					local faceDuToit 			= m_geo.pointsEtFaces		trace_courant		
					
					acrotere			faceDuToit
					
				)
				3: (	---- 1 PAN	----
					toitPentes					&z  1
				)
				4: (	---- 2 PANS	----
					toitPentes					&z  2
				)
			)
		),		
		
		
		------------ FACADES-------------------------
	private
		fn ssBassement  			&z	=(
			
			m_geo.facesContour	 	m_this.trace_courant		z 	ep_ssBassement	
			z += ep_ssBassement
			
-- 			m_geo.creerFacesContour	 	m_this.trace_courant		z 	ep_dalle	m_this
-- 			z += ep_dalle
			
		),
		fn RdC 							&z	=(
			
			m_geo.facesContour	 m_this.trace_courant		z 	m_this.niveaux_hauteur				
			z += m_this.niveaux_hauteur	
			
		),
		fn creer_mur 	_pt_bas		_pt_ht	_pt2 		 ht:	m_matID:	= (
			local hauteur
-- 			debug "creer_mur"
-- 			debug "_pt_bas" var:_pt_bas
-- 			debug "_pt2" var:_pt2
-- 			debug "(distance _pt2 _pt_bas )" var:(distance _pt2 	(polyop.getvert m_this.delegate _pt_bas ) )
			if ht != unsupplied then	hauteur = ht
				else hauteur 	=	m_this.niveaux_hauteur 
			
			local pts_pos_esp = 	#()		
			append pts_pos_esp 	( _pt2 )
			append pts_pos_esp 	( _pt2 + [0,0,hauteur] )
			
			local pts_ids_esp = m_geo.points  pts_pos_esp 	
			append pts_ids_esp 	( _pt_ht )
			append pts_ids_esp 	( _pt_bas )
			
			m_geo.edges  pts_ids_esp 		--	fermer:true		
			local nvlFace = m_geo.pointsEtFaces 	 pts_ids_esp 	
			
			--- mat ID -----
			if m_matID != unsupplied do
				polyop.setFaceMatID	 m_this.delegate		nvlFace	  m_matID
			
			local pt_bas 	= pts_ids_esp[1]
			local pt_ht		= pts_ids_esp[2]
			
			#(pt_bas, pt_ht)
		),
		fn creer_sequence		_pt1		_pt2		_facade					=(
			
			
-- 			-------- DEBUG----------------------
-- 			local chrono_debut = timeStamp ()
-- 			-------- DEBUG----------------------
			
			--- passerelle ----------
			local creer_murPlein = m_this.facades.creer_murPlein
			
			
			------------ ANALYSE ------------------------
			local pt_bas, pt_ht	 
			
			local longueurFacade 		= distance _pt1 _pt2
			local normDir					=	normalize ( _pt2 - _pt1)
			local rot 						= m_outils.get_angle_vecteur		normDir
			local longueur_sequence 	= _facade.sequence_longueur
			local sequence 				= _facade.sequence 		
			local b_espacer 				= _facade.mode == 4
			
			local nbr_espacemts 		= 0
			for compo in sequence do
				if compo.type == #Parametrique do
					if findString compo.param[1].id "#FAC_PES" != undefined do
						nbr_espacemts += 1
					
			local nbrRepetitions 		
			local longueur_restant 			
			local longueur_espacement 			
			case _facade.mode of (
				1:  	(	--- Repeter ----
					nbrRepetitions				= floor ( longueurFacade / longueur_sequence )
					longueur_restant 			= longueurFacade - longueur_sequence * nbrRepetitions
					longueur_espacement 	= longueur_restant / ( 2	+ nbr_espacemts * nbrRepetitions )
					b_espacer = false
				)
				2: 	(	--- Etirer ----
					nbrRepetitions				= 1						
					longueur_restant 			= longueurFacade - longueur_sequence * nbrRepetitions 	
					longueur_espacement 	= longueur_restant / ( 2	+ nbr_espacemts * nbrRepetitions )

				)
				3: 	(	--- Centrer ----					
					nbrRepetitions				= 1		
					longueur_restant 			= longueurFacade - longueur_sequence * nbrRepetitions 	
					longueur_espacement 	= longueur_restant / (  nbr_espacemts * nbrRepetitions )
					
				)
				4:		(	--- Espacer ----	
					nbrRepetitions				= floor ( longueurFacade / longueur_sequence )
					longueur_restant 			= longueurFacade - longueur_sequence * (nbrRepetitions )		
					longueur_espacement 	= longueur_restant / ( 1 + nbr_espacemts * nbrRepetitions)
				)						
			)
			
			------------ CONSTRUCTION ------------------------
			
			---- pour les balcons --------
			local 	balcon_aConstruire = undefined
			local 	balcon_pt_debut 	, balcon_ptID_debut
			
			--- les 3 premiers points --------				
			local pt_accroche_1 	= 	_pt1
			local pt_accroche_2 	= 	pt_accroche_1 + [0,0,m_this.ep_dalle]
			local pt_accroche_3 	= 	pt_accroche_2 + [0,0,m_this.niveaux_hauteur]
			
			local ptsIDs_accroche 		= ( m_geo.points   #( pt_accroche_1 , pt_accroche_2 , pt_accroche_3 )	 	)
			
			
			--- si c'est pas en mode centrer ...
			----- le premier espacement ------------
			if _facade.mode != 3 do (
				
				--- Composant 'Mur plein' temporaire	------
				local compoTmp = creer_murPlein		longueur_espacement
				ptsIDs_accroche = compoTmp.param[1].construire	 ptsIDs_accroche		normDir 
				
			)
			
			----- les repetitions de sequence ------------------
			for i = 1 to nbrRepetitions do (
				
				--- la sequence --------
				for composant in sequence do (
					
					-------- DEBUG----------------------
					local chrono_debut_compo = timeStamp ()
					-------- DEBUG----------------------
					
					case composant.type    of (
						 #Modele:			(
							/* 
							---- on tire au hasare le modele  ------------
							local probaTotal = 0
							for proba in composant.modeles_probas do 
								probaTotal += proba
							local tirage = random  1.  probaTotal
							local modele
							local trouve = false
							local id = 1
							local probacourant = 0
							while not trouve and probacourant <= probaTotal	do (
								probacourant += composant.modeles_probas[id]
								if tirage < probacourant do (
									trouve = true
									modele = composant.modeles[id]
								)
								id += 1
							)
							
							if modele != undefined then	(
								
								-- si le modele est trop long on met un mur plein ----------
								pt2 = pt1 + normDir * modele.longueur	
								if composant.longueur>distance _pt2	pt1   then (	
									
									pt2		=	_pt2							
									local pts_accroche = creer_mur 	pt_bas		pt_ht		pt2 		m_this		
									pt_bas 	= pts_accroche[1]
									pt_ht		= pts_accroche[2]
									
									pt1 = pt2
									
								) else (
								---- sinon, pose du modele -----
									local modeleTmp_id		=	m_this.facades.get_modele_idParam		modele.id		m_this
									local modele_node 		= modeles_import[modeleTmp_id]
									local nv_modele 			= copy modele_node
									
									rotate nv_modele (angleaxis rot [0,0,1])
									nv_modele.pos 				= pt1
									nv_modele.pos.z 				= z
									
									m_this.delegate.attach	nv_modele		modele_node
									
									
									-----	facette du dessus -----
									pt2 = pt1 + normDir * modele.longueur								
									local hauteurQuiReste = 	m_this.niveaux_hauteur 	- modele.hauteur	
									
									local pts_accroche = creer_mur 	pt_bas		pt_ht		pt2 		m_this		ht:hauteurQuiReste	
									pt_bas 	= pts_accroche[1]
									pt_ht		= pts_accroche[2]	
									
									pt1 = pt2
								)
							) -- fin if modele undeinde
							 */
							
						) -- fin modele 
						#Parametrique: 	(
							local pts_accroche 
							local est_espacement 	= findString composant.param[1].id "#FAC_PES" != undefined
							local est_Balcon_deb 	= findString composant.param[1].id "#FAC_PBD" != undefined
							local est_Balcon_fin 	= findString composant.param[1].id "#FAC_PBF" != undefined
							
							---  ESPACEMENT  ----------
							if 	est_espacement 	then (
								
								--- Composant 'Mur plein' temporaire	------
								local compoTmp = creer_murPlein		longueur_espacement 
								ptsIDs_accroche = compoTmp.param[1].construire	 ptsIDs_accroche		normDir 
								
							---  BALCON  ----------
							) else 	if est_Balcon_deb then  (
								balcon_ptID_debut 	= ptsIDs_accroche[1]	
								balcon_pt_debut 		= polyop.getVert 	m_this.delegate		ptsIDs_accroche[1]	
								balcon_aConstruire 	= composant
							) else if 	est_Balcon_fin 	then (
								balcon_aConstruire.longueur 			= distance	(polyop.getVert 	m_this.delegate		ptsIDs_accroche[1]	) 	balcon_pt_debut
								balcon_aConstruire.param[1].construire	 #(balcon_ptID_debut, ptsIDs_accroche[2], ptsIDs_accroche[3])		normDir 
								balcon_aConstruire.longueur 			= 0
								balcon_aConstruire = undefined
							---  DEFAULT  ----------
							) else (
								
								ptsIDs_accroche = composant.param[1].construire	 ptsIDs_accroche		normDir	 		est_DansBalcon:(balcon_aConstruire != undefined )
								
							)
						) -- fin 	#Parametrique
						
					) -- fin case ---------------
					
					
					-------- DEBUG----------------------
					local chrono_fin_compo = timeStamp ()
-- 						debug "creer_sequence		compo" var:composant.nom
-- 						debug "creer_sequence		dur�e compo" var:(   (chrono_fin_compo - chrono_debut_compo ) / 1000.0)
					-------- DEBUG----------------------
				
					
					
				) --- fin de la sequence -----
		
				if b_espacer do (
					
					--- Composant 'Mur plein' temporaire	------
					local compoTmp = creer_murPlein		longueur_espacement 		
					ptsIDs_accroche = compoTmp.param[1].construire	 ptsIDs_accroche		normDir	 
					
	
				)
				
			)  --- fin de la repetition
			
			
			if not b_espacer and  _facade.mode != 3 do (
				
				
				--- le dernier espacement --------				
				--- Composant 'Mur plein' temporaire	------
				local compoTmp = creer_murPlein		longueur_espacement 		
				ptsIDs_accroche = compoTmp.param[1].construire	 ptsIDs_accroche		normDir	 
				
			)
			
-- 			-------- DEBUG----------------------
-- 			local chrono_fin = timeStamp ()
-- 			debug "creer_sequence		dur�e TOTAL" var:(   (chrono_fin - chrono_debut ) / 1000.0)
-- 			-------- DEBUG----------------------
			
		),
		fn etages 								&z	=(
			
			local z_initial = copy z
			
			--- passerelle ----------
			local creer_murPlein = m_this.facades.creer_murPlein
			
			for ssTrace_string in m_this.sousTraces do (
					z  = z_initial
				
					local sousTrace = str_ssTrace ()
-- 					m_this.trace.datasMgr.set_datas_string 		ssTrace_string 		sousTrace
					m_this.trace.sousTrace_fromString  	ssTrace_string 		sousTrace
-- 				set_datas_string 		_datas_string 		_element 	
				
			
				---- boucle �tages ---------------------
-- 				for n_etage = 0 to sousTrace.etages  do (
				for n_etage = 0 to m_this.niveaux_nbre do (
					
					--- filtre par etages ---------------
					local facades_total					= m_this.facades.get_facades ()
					local facades_etages 				= 	filtrer_facades_parEtages		facades_total 	n_etage
					local on_a_une_facade_etage 	= facades_etages.count > 0
					local listePts 							= for idPt in sousTrace.trace collect m_this.trace_courant[idPt]
					
					---- boucle  murs ---------------------
					for id_pt = 1 to listePts.count do	 (
						
						local on_a_une_facade_mur = false
						
						--- les 2 points du mur ----------
						local pt_mur_1 = listePts[ id_pt ]
						local pt_mur_2						
						if id_pt == listePts.count 	then	pt_mur_2 = listePts[ 1 ]
															else	pt_mur_2 = listePts[ id_pt + 1 ]
						pt_mur_1.z = pt_mur_2.z = z
						
						local	mur_longueur 		= distance pt_mur_1 	pt_mur_2
						local	norm_mur 			= normalize ( pt_mur_2 -	pt_mur_1 )
						
						---- si on  a des facades ------
						if 	on_a_une_facade_etage  then (
						
							---  filtre par  murs  ---------------
							local facades_mur		=	filtrer_facades_parMurs		facades_etages	mur_longueur	id_pt
							
							---  filtre par probabilit�s  ---------------						
							local facade_choisi 		= choisir_parProbas		facades_mur	
							
							---- on lance les construction ----------------
							if facade_choisi != undefined and facade_choisi.sequence.count > 0 then (
							--- si on a une facade, on construit la sequence --------------
								creer_sequence		pt_mur_1		pt_mur_2	 facade_choisi			
								on_a_une_facade_mur = true
							)  
							
						) else (
						--- sinon un mur plein --------------
							
							--- Composant 'Mur plein' temporaire	------
							local pt_accroche_1 	= 	pt_mur_1 
							local pt_accroche_2 	= 	pt_mur_1 + [0,0,m_this.ep_dalle]
							local pt_accroche_3 	= 	pt_accroche_2 + [0,0,m_this.niveaux_hauteur]	
							
							local ptsIDs_accroche 	= ( m_geo.points   #( pt_accroche_1 , pt_accroche_2 , pt_accroche_3 )	)
							
							local compoTmp = creer_murPlein		mur_longueur 	
							ptsIDs_accroche 	= compoTmp.param[1].construire	 ptsIDs_accroche		norm_mur 
							
						)
						
					)
					
					z += m_this.niveaux_hauteur + m_this.ep_dalle
					
					/* --- dalle plancher ---
					if ep_dalle  != 0 do (
						local nvlsFaces = m_geo.facesContour	m_this.trace_courant	z 	ep_dalle	m_this
						facesDunEtage  += nvlsFaces
						z += ep_dalle
					)  */
					
				) --- fin boucle etages -------------
					
				
			)
			
			m_geo.facesContour	 	m_this.trace_courant		z 	m_this.ep_dalle
			z += ep_dalle
			
		),
		
		
		
		--------- MODELES -----------------
		fn importer_modeles				=(
			modeles_import =#()
			for modele in m_this.facades.get_modeles ()	 do (
				--- nouveau node -----
				local 	nvNode = convertToPoly (mesh ())
				append 	modeles_import		nvNode
				polyop.deleteFaces	nvNode	(#{1..25} as array)		
					
				m_this.facades.scan.creer_objet		modele			ndDest:nvNode
			)
		),
		fn retirer_modelesImports	   =(			
			for modele in modeles_import	 do delete modele
			modeles_import =#()
		),
		
		
		
		--------- INTERFACE --------------------------------------------------------------------
	public
		fn batiment 	 =(
			with redraw OFF (
				undo off (
					
					local chrono_debut = timeStamp ()
					
					---- creation de la surface de base -------
					m_geo.vider 	()
					
					importer_modeles		()	
					
					local chrono_import = timeStamp ()		--- chrono_debut) / 1000.0
					
					
					local zCourant = -( ep_ssBassement + ep_dalle )
					
					ssBassement 		&zCourant
					local chrono_ssBassement		= timeStamp ()	
					etages				&zCourant
					local chrono_etages				= timeStamp ()	
					toit					&zCourant
					local chrono_toit					= timeStamp ()	
					
					--- Mapping ---
					matrxMapping = matrix3 1 
					rotateZ matrxMapping  ( 90 - (quatToEuler2  m_this.axeP_mtrx.rotationpart).z )
					polyop.applyUVWMap 	m_this.delegate  #box	 tm:matrxMapping  channel:1
					
					
					local chrono_retirerImport		= timeStamp ()	
					retirer_modelesImports ()
					
					local chrono_total				= timeStamp ()	
					
					
					
					
					
					
					--- affichage sortie --------
					debug "Construire b�timent"
					debug "			import" var:(	(   (chrono_import - chrono_debut ) / 1000.0)	as string + "s." )
					debug "			ssBassement" var:( (   ( chrono_ssBassement - chrono_import ) / 1000.0)	as string + "s." )
					debug "			etages" var:( (   (chrono_etages - chrono_ssBassement ) / 1000.0)	as string + "s." )
					debug "			toit" var:(  (  (chrono_toit - chrono_etages ) / 1000.0)	as string + "s." )
					debug "			cleaner import" var:(  (  (chrono_total - chrono_toit ) / 1000.0)	as string + "s." )
					debug "		-----	TOTAL" var:(  (  (chrono_total - chrono_debut ) / 1000.0)	as string + "s." )
					debug "		-----	nbre de verts" var:(  m_this.mesh.verts.count )
					
				)
				displayTempPrompt ("B�timent construit en " +  (  (chrono_total - chrono_debut ) / 1000.0)	as string + "s." ) 10000
			)
			redrawViews () 
		)
	
	
) ---- fin struct construire ------------------


























