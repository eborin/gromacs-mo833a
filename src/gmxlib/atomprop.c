/*
 * 
 *                This source code is part of
 * 
 *                 G   R   O   M   A   C   S
 * 
 *          GROningen MAchine for Chemical Simulations
 * 
 *                        VERSION 3.2.0
 * Written by David van der Spoel, Erik Lindahl, Berk Hess, and others.
 * Copyright (c) 1991-2000, University of Groningen, The Netherlands.
 * Copyright (c) 2001-2004, The GROMACS development team,
 * check out http://www.gromacs.org for more information.

 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * If you want to redistribute modifications, please consider that
 * scientific software is very special. Version control is crucial -
 * bugs must be traceable. We will be happy to consider code for
 * inclusion in the official distribution, but derived work must not
 * be called official GROMACS. Details are found in the README & COPYING
 * files - if they are missing, get the official version at www.gromacs.org.
 * 
 * To help us fund GROMACS development, we humbly ask that you cite
 * the papers on the package - you can find them in the top README file.
 * 
 * For more info, check our website at http://www.gromacs.org
 * 
 * And Hey:
 * GROningen Mixture of Alchemy and Childrens' Stories
 */
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <ctype.h>
#include "sysstuff.h"
#include "smalloc.h"
#include "string2.h"
#include "futil.h"
#include "maths.h"
#include "gmx_fatal.h"
#include "atomprop.h"
#include "maths.h"
#include "macros.h"
#include "index.h"
#include "strdb.h"
#include "copyrite.h"

typedef struct {
  bool   bSet;
  int    nprop,maxprop;
  char   *db;
  double def;
  char   **atomnm;
  char   **resnm;
  bool   *bAvail;
  real   *value;
} aprop_t;

typedef struct gmx_atomprop {
  aprop_t    prop[epropNR];
  t_aa_names *aan;
} gmx_atomprop;



/* NOTFOUND should be smallest, others larger in increasing priority */
enum { NOTFOUND=-4, WILDCARD, WILDPROT, PROTEIN };

/* return number of matching characters, 
   or NOTFOUND if not at least all characters in char *database match */
static int dbcmp_len(char *search, char *database)
{
  int i;
  
  i=0;
  while(search[i] && database[i] && (search[i]==database[i]) )
    i++;
  
  if (database[i])
    i=NOTFOUND;
  return i;
}

static int get_prop_index(aprop_t *ap,t_aa_names *aan,
			  char *resnm,char *atomnm,
			  bool *bExact)
{
  int  i,j=NOTFOUND;
  long int alen,rlen;
  long int malen,mrlen;
  bool bProtein,bProtWild;
  
  bProtein  = is_protein(aan,resnm);
  bProtWild = (strcmp(resnm,"AAA")==0);
  malen = NOTFOUND;
  mrlen = NOTFOUND;
  for(i=0; (i<ap->nprop); i++) {
    rlen = dbcmp_len(resnm, ap->resnm[i]);
    if (rlen == NOTFOUND) {
      if ( (strcmp(ap->resnm[i],"*")==0) ||
	   (strcmp(ap->resnm[i],"???")==0) )
	rlen=WILDCARD;
      else if (strcmp(ap->resnm[i],"AAA")==0)
	rlen=WILDPROT;
    }
    alen = dbcmp_len(atomnm, ap->atomnm[i]);
    if ( (alen > NOTFOUND) && (rlen > NOTFOUND)) {
      if ( ( (alen > malen) && (rlen >= mrlen)) ||
	   ( (rlen > mrlen) && (alen >= malen) ) ) {
	malen = alen;
	mrlen = rlen;
	j     = i;
      }
    }
  }
  
  *bExact = ((malen == (long int)strlen(atomnm)) &&
	     ((mrlen == (long int)strlen(resnm)) || 
	      ((mrlen == WILDPROT) && bProtWild) ||
	      ((mrlen == WILDCARD) && !bProtein && !bProtWild)));
  
  if (debug) {
    fprintf(debug,"searching residue: %4s atom: %4s\n",resnm,atomnm);
    if (j == NOTFOUND)
      fprintf(debug," not succesful\n");
    else
      fprintf(debug," match: %4s %4s\n",ap->resnm[j],ap->atomnm[j]);
  }
  return j;
}

static void add_prop(aprop_t *ap,t_aa_names *aan,
		     char *resnm,char *atomnm,
		     real p,int line) 
{
  int  i,j;
  bool bExact;
  
  j = get_prop_index(ap,aan,resnm,atomnm,&bExact);
  
  if (!bExact) {
    if (ap->nprop >= ap->maxprop) {
      ap->maxprop += 10;
      srenew(ap->resnm,ap->maxprop);
      srenew(ap->atomnm,ap->maxprop);
      srenew(ap->value,ap->maxprop);
      srenew(ap->bAvail,ap->maxprop);
      for(i=ap->nprop; (i<ap->maxprop); i++) {
	ap->atomnm[i] = NULL;
	ap->resnm[i]  = NULL;
	ap->value[i]  = 0;
	ap->bAvail[i] = FALSE;
      }
    }
    upstring(atomnm);
    upstring(resnm);
    ap->atomnm[ap->nprop] = strdup(atomnm);
    ap->resnm[ap->nprop]  = strdup(resnm);
    j = ap->nprop;
    ap->nprop++;
  }
  if (ap->bAvail[j]) {
    if (ap->value[j] == p)
      fprintf(stderr,"Warning double identical entries for %s %s %g on line %d in file %s\n",
	      resnm,atomnm,p,line,ap->db);
    else {
      fprintf(stderr,"Warning double different entries %s %s %g and %g on line %d in file %s\n"
	      "Using last entry (%g)\n",
	      resnm,atomnm,p,ap->value[j],line,ap->db,p);
      ap->value[j] = p;
    }
  }
  else {
    ap->bAvail[j] = TRUE;
    ap->value[j]  = p;
  }
}

static void read_prop(gmx_atomprop_t aps,int eprop,double factor)
{
  gmx_atomprop *ap2 = (gmx_atomprop*) aps;
  FILE   *fp;
  char   line[STRLEN],resnm[32],atomnm[32];
  double pp;
  int    line_no;
  aprop_t *ap;

  ap = &ap2->prop[eprop];

  fp      = libopen(ap->db);
  line_no = 0;
  while(get_a_line(fp,line,STRLEN)) {
    line_no++;
    if (sscanf(line,"%s %s %lf",resnm,atomnm,&pp) == 3) {
      pp *= factor;
      add_prop(ap,aps->aan,resnm,atomnm,pp,line_no);
    }
    else 
      fprintf(stderr,"WARNING: Error in file %s at line %d ignored\n",
	      ap->db,line_no);
  }
	
  /* for libraries we can use the low-level close routines */
  fclose(fp);

  ap->bSet = TRUE;
}

static void atomprop_name_warning(const char *type)
{
  printf("WARNING: %s will be determined based on residue and atom names,\n"
	 "         this can deviate from the real mass of the atom type\n",
	 type);
}

static void set_prop(gmx_atomprop_t aps,int eprop) 
{
  gmx_atomprop *ap2 = (gmx_atomprop*) aps;
  const char *fns[epropNR]  = { "atommass.dat", "vdwradii.dat", "dgsolv.dat", "electroneg.dat", "elements.dat" };
  double fac[epropNR] = { 1.0,    1.0,  418.4, 1.0, 1.0 };
  double def[epropNR] = { 12.011, 0.14, 0.0, 2.2, -1 };
  aprop_t *ap;

  if (eprop == epropMass) {
    atomprop_name_warning("masses");
  }
  if (eprop == epropVDW) {
    atomprop_name_warning("vdwradii");
  }
  

  ap = &ap2->prop[eprop];
  ap->db  = strdup(fns[eprop]);
  ap->def = def[eprop];
  read_prop(aps,eprop,fac[eprop]);

  printf("Entries in %s: %d\n",ap->db,ap->nprop);
}

gmx_atomprop_t gmx_atomprop_init(void)
{
  gmx_atomprop *aps;
  int p;

  snew(aps,1);

  aps->aan = get_aa_names();

  for(p=0; p<epropNR; p++) 
    set_prop(aps,p);

  return (gmx_atomprop_t)aps;
}

static void destroy_prop(aprop_t *ap)
{
  int i;

  sfree(ap->db);

  for(i=0; i<ap->nprop; i++) {
    sfree(ap->atomnm[i]);
    sfree(ap->resnm[i]);
  }
  sfree(ap->atomnm);
  sfree(ap->resnm);
  sfree(ap->bAvail);
  sfree(ap->value);
}

void gmx_atomprop_destroy(gmx_atomprop_t aps)
{
  gmx_atomprop *ap = (gmx_atomprop*) aps;
  int p;

  if (aps == NULL) {
    printf("\nWARNING: gmx_atomprop_destroy called with a NULL pointer\n\n");
    return;
  }

  for(p=0; p<epropNR; p++) {
    destroy_prop(&ap->prop[p]);
  }

  done_aa_names(&ap->aan);

  sfree(ap);
}

bool gmx_atomprop_query(gmx_atomprop_t aps,
			int eprop,const char *resnm,const char *atomnm,
			real *value)
{
  gmx_atomprop *ap = (gmx_atomprop*) aps;
  size_t i;
  int  j;
#define MAXQ 32
  char atomname[MAXQ],resname[MAXQ];
  bool bExact;

  if ((strlen(atomnm) > MAXQ-1) || (strlen(resnm) > MAXQ-1)) {
    if (debug)
      fprintf(debug,"WARNING: will only compare first %d characters\n",
	      MAXQ-1);
  }
  if (isdigit(atomnm[0])) {
    /* put digit after atomname */
    for (i=1; (i<min(MAXQ-1,strlen(atomnm))); i++)
      atomname[i-1] = atomnm[i];
    atomname[i++] = atomnm[0];
    atomname[i]   = '\0';
  } 
  else { 
    strncpy(atomname,atomnm,MAXQ-1);
  }
  upstring(atomname);
  strncpy(resname,resnm,MAXQ-1);
  upstring(resname);
  
  j = get_prop_index(&(ap->prop[eprop]),ap->aan,resname,
		     atomname,&bExact);
  
  if (j >= 0) {
    *value = ap->prop[eprop].value[j];
    return TRUE;
  }
  else {
    *value = ap->prop[eprop].def;
    return FALSE;
  }
}

char *gmx_atomprop_element(gmx_atomprop_t aps,int atomnumber)
{
  gmx_atomprop *ap = (gmx_atomprop*) aps;
  int i;
  
  for(i=0; (i<ap->prop[epropElement].nprop); i++) {
    if (gmx_nint(ap->prop[epropElement].value[i]) == atomnumber) {
      return ap->prop[epropElement].atomnm[i];
    }
  }
  return NULL;
}

int gmx_atomprop_atomnumber(gmx_atomprop_t aps,const char *elem)
{
  gmx_atomprop *ap = (gmx_atomprop*) aps;
  int i;
  
  for(i=0; (i<ap->prop[epropElement].nprop); i++) {
    if (strcasecmp(ap->prop[epropElement].atomnm[i],elem) == 0) {
      return gmx_nint(ap->prop[epropElement].value[i]);
    }
  }
  return NOTSET;
}
