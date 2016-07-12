Require Import DynamicNet.
Require Import Chord.
Require Import ChordProof.
Import List.
Require Import InfSeqExt.infseq.
Require Import StructTact.StructTactics.
Require Import StructTact.Util.
Require Import mathcomp.ssreflect.ssreflect.

Require Import Classical. (* yuck *)

Set Bullet Behavior "Strict Subproofs".

Section LabeledChord.
  Variable SUCC_LIST_LEN : nat.
  Variable hash : addr -> id.
  Variable base : list addr.

  Notation msg := (msg addr payload).
  Notation global_state := (global_state addr payload data timeout).
  Notation msgs := (msgs addr payload data timeout).
  Notation e_recv := (e_recv addr payload timeout).
  Notation e_timeout := (e_timeout addr payload timeout).
  Notation trace := (trace addr payload data timeout).
  Notation update := (update addr addr_eq_dec data).

  Inductive label :=
  | RecvMsg : addr -> addr -> payload -> label
  | Timeout : addr -> timeout -> label.

  Definition label_eq_dec : forall x y : label, {x = y} + {x <> y}.  
  Proof.
    decide equality; eauto using addr_eq_dec, payload_eq_dec, timeout_eq_dec.
  Defined.

  Notation occ_gst := (occ_gst addr payload data timeout label).
  Notation occurrence := (occurrence addr payload data timeout label).
  Notation recv_handler := (recv_handler SUCC_LIST_LEN hash).
  Notation timeout_handler := (timeout_handler hash).

  Definition timeout_handler_l (h : addr) (st : data) (t : timeout) :=
    (timeout_handler h st t, Timeout h t).

  Definition recv_handler_l (src : addr) (dst : addr) (st : data) (msg : payload) :=
    (recv_handler src dst st msg, RecvMsg src dst msg).

  Notation labeled_step_dynamic := (labeled_step_dynamic addr addr_eq_dec payload data timeout timeout_eq_dec label recv_handler_l timeout_handler_l timeout_constraint).
  Notation lb_execution := (lb_execution addr addr_eq_dec payload data timeout timeout_eq_dec label recv_handler_l timeout_handler_l timeout_constraint).
  Notation strong_local_fairness := (strong_local_fairness addr addr_eq_dec payload data timeout timeout_eq_dec label recv_handler_l timeout_handler_l timeout_constraint).
  Notation inf_occurred := (inf_occurred addr payload data timeout label).
  Notation enabled := (enabled addr addr_eq_dec payload data timeout timeout_eq_dec label recv_handler_l timeout_handler_l timeout_constraint).
  Notation l_enabled := (l_enabled addr addr_eq_dec payload data timeout timeout_eq_dec label recv_handler_l timeout_handler_l timeout_constraint). 
  Notation occurred := (occurred addr payload data timeout label).
  Notation nodes := (nodes addr payload data timeout).
  Notation failed_nodes := (failed_nodes addr payload data timeout).
  Notation sigma := (sigma addr payload data timeout).
  Notation timeouts := (timeouts addr payload data timeout).
  Notation apply_handler_result := (apply_handler_result addr addr_eq_dec payload data timeout timeout_eq_dec).
  Notation update_msgs := (update_msgs addr payload data timeout).

  Definition bool_of_sumbool {A B : Prop} (x : {A} + {B}) : bool :=
    match x with
    | left _ => true
    | right _ => false
    end.

  Definition failed (gst : global_state) (p : pointer) :=
    let (_, h) := p in
    bool_of_sumbool (In_dec addr_eq_dec h (failed_nodes gst)).

  (* assuming sigma gst h = Some st *)
  Definition undetected_dead_successors (gst : global_state) (st : data) (h : addr) : nat :=
    length (filter (failed gst) (succ_list st)).

  Lemma l_enabled_RecvMsg_In_msgs :
    forall e src dst m d,
      In dst (nodes (occ_gst e)) ->
      ~ In dst (failed_nodes (occ_gst e)) ->
      In (src, (dst, m)) (msgs (occ_gst e)) ->
      sigma (occ_gst e) dst = Some d ->
      l_enabled (RecvMsg src dst m) e.
  Proof.
  move => e src dst m d H_in_n H_in_f H_in H_s.
  find_apply_lem_hyp in_split.
  break_exists.
  rewrite /l_enabled /enabled.
  case H_r: (recv_handler_l src dst d m) => [[[[st ms] newts] clearedts] lb].
  have H_lb: lb = RecvMsg src dst m.
    rewrite /recv_handler_l /= in H_r.
    by tuple_inversion.
  rewrite H_lb {H_lb} in H_r.
  pose gst' := apply_handler_result
                 dst
                 (st, ms, newts, clearedts)
                 (e_recv (src, (dst, m)))
                 (update_msgs (occ_gst e) (x ++ x0)).
  exists gst'.
  by eapply LDeliver_node; eauto.
  Qed.

  Ltac break_labeled_step :=
    match goal with
      | H : labeled_step_dynamic _ _ _ |- _ =>
        destruct H
    end; subst.

  Ltac inv_labeled_step :=
    match goal with
      | H : labeled_step_dynamic _ _ _ |- _ =>
        inv H; try now (unfold recv_handler_l, timeout_handler_l in *; tuple_inversion)
    end.

  Ltac invc_labeled_step :=
    match goal with
      | H : labeled_step_dynamic _ _ _ |- _ =>
        invc H; try now (unfold recv_handler_l, timeout_handler_l in *; tuple_inversion)
    end.

  Lemma sigma_ahr_updates :
    forall gst n st ms nts cts e,
      sigma (apply_handler_result n (st, ms, nts, cts) e gst) n = Some st.
  Proof.
    unfold apply_handler_result, update.
    simpl.
    intuition. 
    break_if; auto || congruence.
  Qed.

  Lemma sigma_ahr_passthrough :
    forall gst n st ms nts cts e h d,
      n <> h ->
      sigma gst h = Some d ->
      sigma (apply_handler_result n (st, ms, nts, cts) e gst) h = Some d.
  Proof.
    unfold apply_handler_result, update.
    simpl.
    intuition. 
    break_if; auto || congruence.
  Qed.

  Lemma labeled_step_preserves_state_existing :
    forall gst gst' l h d,
      sigma gst h = Some d ->
      labeled_step_dynamic gst l gst' ->
      exists d',
        sigma gst' h = Some d'.
  Proof.
    intuition.
    break_labeled_step;
      match goal with
      | H: In ?n (nodes _) |- exists _, sigma _ ?h = _ => destruct (addr_eq_dec n h)
      end;
      subst_max;
      eexists;
      eauto using sigma_ahr_updates, sigma_ahr_passthrough.
  Qed.

  Lemma other_elements_remain_after_removal :
    forall A (l xs ys : list A) (a b : A),
      l = xs ++ b :: ys ->
      In a l ->
      a <> b ->
      In a (xs ++ ys).
  Proof.
    intuition.
    subst_max.
    do_in_app.
    break_or_hyp.
    - intuition.
    - find_apply_lem_hyp in_inv.
      break_or_hyp; auto using in_or_app || congruence.
  Qed.

  Lemma define_msg_from_recv_step_equality :
    forall m d st ms nts cts src dst p,
      recv_handler_l (fst m) (fst (snd m)) d (snd (snd m)) = (st, ms, nts, cts, RecvMsg src dst p) ->
      (m = (src, (dst, p)) /\ fst m = src /\ fst (snd m) = dst /\ snd (snd m) = p).
  Proof.
    unfold recv_handler_l.
    intuition;
      now tuple_inversion.
  Qed.

  Ltac recover_msg_from_recv_step_equality :=
    find_copy_apply_lem_hyp define_msg_from_recv_step_equality;
    break_and.

  Ltac recover_msg_from_recv_step_equality_clear :=
    find_apply_lem_hyp define_msg_from_recv_step_equality;
    break_and.

  Lemma elim_labeled_step_recv :
    forall gst gst' src dst p,
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
      exists st xs ys st' ms newts clearedts,
        sigma gst dst = Some st /\
        msgs gst = xs ++ (src, (dst, p)) :: ys /\
        recv_handler_l src dst st p = (st', ms, newts, clearedts, RecvMsg src dst p) /\
        gst' = (apply_handler_result dst
                                     (st', ms, newts, clearedts)
                                     (e_recv (src, (dst, p)))
                                     (update_msgs gst (xs ++ ys))).
  Proof.
    intuition.
    inv_labeled_step.
    recover_msg_from_recv_step_equality.
    repeat find_rewrite.
    repeat eexists; eauto.
  Qed.

  Lemma irrelevant_message_not_removed :
    forall m p dst src to from gst gst',
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
      In (from, (to, m)) (msgs gst) ->
      (from, (to, m)) <> (src, (dst, p)) ->
      In (from, (to, m)) (msgs gst').
  Proof.
    intuition.
    inv_labeled_step.
    apply in_or_app.
    right.
    recover_msg_from_recv_step_equality.
    eapply other_elements_remain_after_removal; eauto.
    now repeat find_rewrite.
  Qed.

  Ltac destruct_recv_handler_l :=
    match goal with
      |- context[recv_handler_l ?from ?to ?st ?p] =>
      unfold recv_handler_l;
        destruct (recv_handler from to st p) as [[[?st ?ms] ?cts] ?nts] eqn:?H
    end.

  Lemma when_RecvMsg_enabled :
    forall from to p gst,
      In to (nodes gst) ->
      ~ In to (failed_nodes gst) ->
      (exists st, sigma gst to = Some st) ->
      In (from, (to, p)) (msgs gst) ->
      enabled (RecvMsg from to p) gst.
  Proof.
    intuition.
    find_apply_lem_hyp in_split.
    break_exists.
    match goal with
      | H: sigma ?gst ?to = Some ?d |- enabled (RecvMsg ?from ?to ?p) ?gst =>
        assert (exists st ms nts cts, recv_handler_l from to d p = (st, ms, nts, cts, RecvMsg from to p))
    end.
    destruct_recv_handler_l.
    repeat eexists.
    break_exists.
    unfold enabled.
    eauto using LDeliver_node.
  Qed.

  Lemma recv_implies_state_exists :
    forall gst gst' gst'' from to src dst p m,
      labeled_step_dynamic gst (RecvMsg from to p) gst'  ->
      labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
      exists st,
        sigma gst' dst = Some st.
  Proof.
    intuition.
    invc_labeled_step.
    invc_labeled_step.
    recover_msg_from_recv_step_equality_clear.
    recover_msg_from_recv_step_equality_clear.
    repeat find_rewrite.
    unfold update_msgs.
    destruct (addr_eq_dec to dst).
    - repeat find_rewrite.
      eauto using sigma_ahr_updates.
    - eauto using sigma_ahr_passthrough.
  Qed.

  Lemma recv_implies_msg_in_before :
    forall gst gst' src dst p,
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
      In (src, (dst, p)) (msgs gst).
  Proof.
    intuition.
    invc_labeled_step.
    recover_msg_from_recv_step_equality_clear.
    repeat find_rewrite.
    auto using in_or_app, in_eq.
  Qed.

  Lemma recv_implies_msg_in_after :
    forall gst gst' gst'' dst to src from m p,
      labeled_step_dynamic gst (RecvMsg from to p) gst' ->
      labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
      (src, (dst, m)) <> (from, (to, p)) ->
      In (src, (dst, m)) (msgs gst').
  Proof.
    intuition.
    eapply irrelevant_message_not_removed.
    - eauto.
    - invc_labeled_step.
      invc_labeled_step.
      recover_msg_from_recv_step_equality_clear.
      recover_msg_from_recv_step_equality_clear.
      match goal with
      | H: msgs ?gst = _ ++ ?packet :: _,
        H': ?packet = ?tuple
        |- In ?tuple (msgs ?gst) =>
        rewrite H; rewrite H'
      end.
      auto using in_or_app, in_eq.
    - congruence.
  Qed.

  Ltac construct_gst_RecvMsg :=
    match goal with
    | Hst: sigma ?gst ?d = Some ?st,
      Hmsgs: msgs ?gst = ?xs ++ (?s, (?d, ?p)) :: ?ys
      |- enabled (RecvMsg ?s ?d ?p) ?gst =>
      destruct (recv_handler_l s d st p) as [[[[?st' ?ms] ?nts] ?cts] ?l] eqn:?H;
        remember (apply_handler_result
                    d
                    (st', ms, nts, cts)
                    (e_recv (s, (d, p)))
                    (update_msgs gst (xs ++ ys))) as egst
    end.

  Lemma recv_implies_node_in :
    forall gst gst' src dst p,
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
       In dst (nodes gst).
  Proof.
    intuition.
    invc_labeled_step.
  Qed.

  Lemma recv_implies_node_not_failed :
    forall gst gst' src dst p,
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
      ~ In dst (failed_nodes gst).
  Proof.
    intuition.
    invc_labeled_step.
  Qed.

  Lemma failed_nodes_never_added :
    forall gst gst' l h,
      labeled_step_dynamic gst l gst' ->
      ~ In h (failed_nodes gst) ->
      ~ In h (failed_nodes gst').
  Proof.
    intuition.
    now invc_labeled_step.
  Qed.

  Lemma failed_nodes_never_removed :
    forall gst gst' l h,
      labeled_step_dynamic gst l gst' ->
      In h (failed_nodes gst) ->
      In h (failed_nodes gst').
  Proof.
    intuition.
    now invc_labeled_step.
  Qed.

  Lemma nodes_never_removed :
    forall gst gst' l h,
      labeled_step_dynamic gst l gst' ->
      In h (nodes gst) ->
      In h (nodes gst').
  Proof.
    intuition.
    match goal with
    | H: labeled_step_dynamic _ _ _ |- _ => destruct H eqn:?H
    end;
      now invc_labeled_step.
  Qed.

  Lemma labeled_step_dynamic_neq_payload_enabled :
    forall gst gst' gst'' to from m p,
      labeled_step_dynamic gst (RecvMsg from to p) gst' ->
      labeled_step_dynamic gst (RecvMsg from to m) gst'' ->
      m <> p ->
      enabled (RecvMsg from to m) gst'.
  Proof.
    intuition.
    apply when_RecvMsg_enabled.
    - eauto using recv_implies_node_in, nodes_never_removed.
    - eauto using recv_implies_node_not_failed, failed_nodes_never_added.
    - eauto using recv_implies_state_exists.
    - eapply irrelevant_message_not_removed.
      * eauto.
      * eauto using recv_implies_msg_in_before.
      * congruence.
  Qed.

  Lemma labeled_step_dynamic_neq_src_enabled :
    forall gst gst' gst'' to src from m p,
      labeled_step_dynamic gst (RecvMsg from to p) gst' ->
      labeled_step_dynamic gst (RecvMsg src to m) gst'' ->
      src <> from ->
      enabled (RecvMsg src to m) gst'.
  Proof.
    intuition.
    apply when_RecvMsg_enabled.
    - eauto using recv_implies_node_in, nodes_never_removed.
    - eauto using recv_implies_node_not_failed, failed_nodes_never_added.
    - eauto using recv_implies_state_exists.
    - eapply irrelevant_message_not_removed.
      * eauto.
      * eauto using recv_implies_msg_in_before.
      * congruence.
  Qed.
  
  Lemma labeled_step_dynamic_neq_dst_enabled :
    forall gst gst' gst'' dst to src from m p,
      labeled_step_dynamic gst (RecvMsg from to p) gst' ->
      labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
      dst <> to ->
      enabled (RecvMsg src dst m) gst'.
  Proof.
    intuition.
    apply when_RecvMsg_enabled.
    - eauto using recv_implies_node_in, nodes_never_removed.
    - eauto using recv_implies_node_not_failed, failed_nodes_never_added.
    - eauto using recv_implies_state_exists.
    - eapply irrelevant_message_not_removed.
      * eauto.
      * eauto using recv_implies_msg_in_before.
      * congruence.
  Qed.

  Lemma recv_implies_state_exists_after_timeout :
    forall gst gst' gst'' h t src dst m,
      labeled_step_dynamic gst (Timeout h t) gst'  ->
      labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
      exists st,
        sigma gst' dst = Some st.
  Proof.
    intuition.
    invc_labeled_step.
    invc_labeled_step.
    match goal with
    | |- context[sigma (apply_handler_result ?h _ _ _) ?dst] =>
      destruct (addr_eq_dec h dst)
    end.
    - subst.
      eauto using sigma_ahr_updates.
    - recover_msg_from_recv_step_equality_clear.
      repeat find_rewrite.
      eauto using sigma_ahr_passthrough.
  Qed.

  Lemma recv_implies_message_exists_after_timeout :
    forall gst gst' gst'' dst src m h t,
    labeled_step_dynamic gst (Timeout h t) gst' ->
    labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
    In (src, (dst, m)) (msgs gst').
  Proof.
    intuition.
    find_copy_eapply_lem_hyp recv_implies_msg_in_before.
    invc_labeled_step.
    invc_labeled_step.
    recover_msg_from_recv_step_equality_clear.
    apply in_or_app.
    right.
    assumption.
  Qed.

  Lemma labeled_step_dynamic_timeout_enabled :
    forall gst gst' gst'' dst src m h t,
    labeled_step_dynamic gst (Timeout h t) gst' ->
    labeled_step_dynamic gst (RecvMsg src dst m) gst'' ->
    enabled (RecvMsg src dst m) gst'.
  Proof.
    intuition.
    apply when_RecvMsg_enabled.
    - eauto using recv_implies_node_in, nodes_never_removed.
    - eauto using recv_implies_node_not_failed, failed_nodes_never_added.
    - eauto using recv_implies_state_exists_after_timeout.
    - eauto using recv_implies_message_exists_after_timeout.
  Qed.

  Lemma RecvMsg_enabled_until_occurred :
    forall s, lb_execution s ->
      forall src dst m, l_enabled (RecvMsg src dst m) (hd s) ->
        weak_until (now (l_enabled (RecvMsg src dst m)))
              (now (occurred (RecvMsg src dst m)))
              s.
  Proof.
    cofix c.
    case => /=.
    case => /= gst.
    case => [from to p|h t].
    - case.
      case => /= gst' lb' s H_exec src dst m H_en.
      inversion H_exec; subst_max.
      simpl in *.
      case (addr_eq_dec dst to) => H_dec_dst.
        case (addr_eq_dec src from) => H_dec_src.
          case (payload_eq_dec m p) => H_dec_m.
            subst_max.
            exact: W0.
          subst_max.
          apply: W_tl; first by [].
          apply: c => //=.
          unfold l_enabled in *.
          simpl in *.
          unfold enabled in H_en.
          break_exists.
          move: H1 H H_dec_m.
          exact: labeled_step_dynamic_neq_payload_enabled.
        subst_max.
        apply: W_tl; first by [].
        apply: c => //=.
        unfold l_enabled in *.
        simpl in *.
        unfold enabled in H_en.
        break_exists.
        move: H1 H H_dec_src.
        exact: labeled_step_dynamic_neq_src_enabled.
      apply: W_tl; first by [].
      apply: c => //=.
      unfold l_enabled in *.
      simpl in *.
      unfold enabled in H_en.
      break_exists.
      move: H1 H H_dec_dst.
      exact: labeled_step_dynamic_neq_dst_enabled.
    - case.
      case => /= gst' lb' s H_exec src dst m H_en.
      inversion H_exec; subst_max.
      simpl in *.
      rewrite /l_enabled /= in H_en.
      apply: W_tl; first by [].
      apply: c => //=.
      unfold l_enabled in *.
      simpl in *.
      unfold enabled in H_en.
      break_exists.
      move: H1 H.
      exact: labeled_step_dynamic_timeout_enabled.
  Qed.

  Lemma RecvMsg_eventually_occurred :
    forall s, lb_execution s ->
         strong_local_fairness s ->
         forall src dst m d, 
           In dst (nodes (occ_gst (hd s))) ->
           ~ In dst (failed_nodes (occ_gst (hd s))) ->
           In (src, (dst, m)) (msgs (occ_gst (hd s))) ->
           sigma (occ_gst (hd s)) dst = Some d ->
           eventually (now (occurred (RecvMsg src dst m))) s.
  Proof.
    move => s H_exec H_fair src dst m d H_in_n H_in_f H_in_m H_s.
    set P := eventually _.
    case (classic (P s)) => //.
    rewrite /P {P} => H_ev.
    suff H_suff: inf_occurred (RecvMsg src dst m) s by inversion H_suff.
    apply: H_fair.
    apply: always_inf_often.
    apply not_eventually_always_not in H_ev.    
    move: H_ev.
    apply: weak_until_always_not_always.
    apply: RecvMsg_enabled_until_occurred => //.
    move: H_s.
    exact: l_enabled_RecvMsg_In_msgs.
  Qed.

  Lemma timeout_step_satisfies_constraint :
    forall gst h t gst',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      timeout_constraint gst h t.
  Proof.
    move => gst h t gst' H_step.
    now invc_labeled_step.
  Qed.

  Lemma when_Timeout_enabled :
    forall h t st gst,
      In h (nodes gst) ->
      ~ In h (failed_nodes gst) ->
      sigma gst h = Some st ->
      In t (timeouts gst h) ->
      timeout_constraint gst h t ->
      enabled (Timeout h t) gst.
  Proof.
    move => h t st gst H_in H_live H_st H_t H_constraint.
    unfold enabled.
    case H_r: (timeout_handler_l h st t) => [[[[st' ms] nts] cts] l].
    pose gst' := apply_handler_result
                   h
                   (st', ms, nts, t :: cts)
                   (e_timeout h t)
                   gst.
    have H_l: l = Timeout h t.
      rewrite /timeout_handler_l /= in H_r.
      by tuple_inversion.
    subst_max.
    exists gst'.
    now eapply LTimeout; eauto.
  Qed.

  Lemma timeout_implies_node_exists :
    forall gst h t gst',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      In h (nodes gst).
  Proof.
    intuition.
    invc_labeled_step.
  Qed.

  Lemma timeout_implies_node_not_failed :
    forall gst h t gst',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      ~ In h (failed_nodes gst).
  Proof.
    intuition.
    invc_labeled_step.
  Qed.

  Lemma timeout_implies_state_exists :
    forall gst h t gst',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      exists st,
        sigma gst h = Some st.
  Proof.
    intuition.
    invc_labeled_step.
    unfold timeout_handler_l in *.
    tuple_inversion.
    by eauto.
  Qed.

  Lemma update_characterization : forall f x y,
      update f x y x = Some y.
  Proof.
    intuition.
    unfold update.
    case (addr_eq_dec x x) => //.
  Qed.

  Lemma states_not_removed_by_recv_step :
    forall gst gst' h st src dst p,
      labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
      sigma gst h = Some st ->
      exists d,
        sigma gst' h = Some d.
  Proof.
    move => gst gst' h st src dst p H_step H_st.
    invc_labeled_step.
    recover_msg_from_recv_step_equality_clear.
    simpl.
    repeat find_rewrite.
    case (addr_eq_dec h dst).
    - move => H_eq.
      subst_max.
      eexists.
      exact: update_characterization.
    - move => H_neq.
      exists st.
      rewrite <- H_st.
      move: H_neq.
      exact: update_fixes_other_arguments.
  Qed.

  Lemma timeout_step_implies_timeout_exists :
    forall gst gst' h t,
      labeled_step_dynamic gst (Timeout h t) gst' ->
      In t (timeouts gst h).
  Proof.
    intuition.
    invc_labeled_step.
  Qed.

  Lemma recv_handler_keeps_timeouts_satisfying_constraint :
   forall gst src dst p gst' t h,
     labeled_step_dynamic gst (RecvMsg src dst p) gst' ->
     In t (timeouts gst h) ->
     timeout_constraint gst h t ->
     In t (timeouts gst' h).
  Admitted.

  Lemma request_constraint_prevents_recv_adding_msgs :
    forall gst from to m gst' h dst p gst'' q,
    labeled_step_dynamic gst (RecvMsg from to m) gst' ->
    labeled_step_dynamic gst (Timeout h (Request dst p)) gst'' ->
    request_response_pair p q ->
    ~ In (dst, (h, q)) (msgs gst) ->
    ~ In (dst, (h, q)) (msgs gst').
  Admitted.

  Lemma labeled_step_dynamic_recv_timeout_enabled :
    forall gst gst' gst'' a b m h t,
      labeled_step_dynamic gst (RecvMsg a b m) gst' ->
      labeled_step_dynamic gst (Timeout h t) gst'' ->
      enabled (Timeout h t) gst'.
  Proof.
    move => gst gst' gst'' a b m h t H_recv H_timeout.
    find_copy_apply_lem_hyp timeout_step_satisfies_constraint.
    find_copy_apply_lem_hyp timeout_implies_state_exists.
    break_exists_name st.
    copy_eapply states_not_removed_by_recv_step H_recv; eauto.
    break_exists_name st'.
    eapply when_Timeout_enabled.
    - find_apply_lem_hyp timeout_implies_node_exists.
      move: H_recv H_timeout.
      exact: nodes_never_removed.
    - find_apply_lem_hyp timeout_implies_node_not_failed.
      move: H_recv H_timeout.
      exact: failed_nodes_never_added.
    - by eauto.
    - invc_labeled_step.
      inv_labeled_step.
      eapply recv_handler_keeps_timeouts_satisfying_constraint; eauto.
      (* TODO make this a lemma/tactic like recover_msg_from_... *)
      unfold timeout_handler_l in *.
      now tuple_inversion.
    - match goal with
      | H: timeout_constraint _ _ _ |- _ => invc H
      end.
      * apply Tick_unconstrained.
      * apply Request_needs_dst_dead_and_no_msgs.
        + eapply failed_nodes_never_removed; eauto.
        + move => q H_pair.
          now eapply request_constraint_prevents_recv_adding_msgs; eauto.
  Qed.

  Lemma labeled_step_dynamic_timeout_neq_h_timeout_enabled :
    forall gst gst' gst'' h h' t t',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      labeled_step_dynamic gst (Timeout h' t') gst'' ->
      h <> h' ->
      enabled (Timeout h' t') gst'.
  Admitted.

  Lemma labeled_step_dynamic_timeout_neq_timeout_enabled :
    forall gst gst' gst'' h h' t t',
      labeled_step_dynamic gst (Timeout h t) gst' ->
      labeled_step_dynamic gst (Timeout h' t') gst'' ->
      t <> t' ->
      enabled (Timeout h' t') gst'.
  Admitted.

  Lemma Timeout_enabled_until_occurred :
    forall s h t,
      lb_execution s ->
      l_enabled (Timeout h t) (hd s) ->
      weak_until (now (l_enabled (Timeout h t)))
                 (now (occurred (Timeout h t)))
              s.
  Proof.
    cofix c.
    case => /=.
    case => /= gst.
    case => [from to p|h t].
    - case.
      case => /= gst' lb' s h t H_exec H_en.
      inversion H_exec as [o o' s' H_step_recv H_exec' H_oeq]; subst_max.
      simpl in *.
      case (addr_eq_dec h to) => H_dec_h.
      * subst_max.
        apply: W_tl => //.
        apply: c => //=.
        unfold l_enabled in *.
        unfold enabled in H_en.
        break_exists_name gst''.
        move: H_step_recv H_en.
        simpl in *.
        exact: labeled_step_dynamic_recv_timeout_enabled.
      * apply: W_tl => //.
        apply: c => //=.
        unfold l_enabled in *.
        unfold enabled in H_en.
        break_exists_name gst''.
        move: H_step_recv H_en.
        exact: labeled_step_dynamic_recv_timeout_enabled.
    - case.
      case => /= gst' l s h' t' H_exec H_en.
      inversion H_exec as [o o' s' H_step_timeout H_exec' H_oeq]; subst_max.
      simpl in *.
      case (addr_eq_dec h h') => H_dec_h.
      * subst_max.
        case (timeout_eq_dec t t') => H_dec_t.
        + subst_max.
          exact: W0.
        + apply W_tl; first by [].
          apply: c => //=.
          unfold l_enabled in *.
          unfold enabled in H_en.
          break_exists_name gst''.
          simpl in *.
          move: H_step_timeout H_en H_dec_t.
          exact: labeled_step_dynamic_timeout_neq_timeout_enabled.
      * apply W_tl; first by [].
        apply: c => //=.
        unfold l_enabled in *.
        unfold enabled in H_en.
        break_exists_name gst''.
        move: H_step_timeout H_en H_dec_h.
        exact: labeled_step_dynamic_timeout_neq_h_timeout_enabled.
  Qed.

  Lemma l_enabled_Timeout_In_timeouts :
    forall h t e st,
      In h (nodes (occ_gst e)) ->
      ~ In h (failed_nodes (occ_gst e)) ->
      In t (timeouts (occ_gst e) h) ->
      sigma (occ_gst e) h = Some st ->
      timeout_constraint (occ_gst e) h t ->
      l_enabled (Timeout h t) e.
  Proof.
    move => h t e st H_node H_live H_t H_st.
    unfold l_enabled, enabled.
    set (gst := occ_gst e) in *.
    case H_r: (timeout_handler_l h st t) => [[[[st' ms] newts] clearedts] lb].
    rewrite /timeout_handler_l /= in H_r.
    have H_lb: lb = Timeout h t by tuple_inversion.
    rewrite H_lb {H_lb} in H_r.
    pose gst' := apply_handler_result
                   h
                   (st', ms, newts, t :: clearedts)
                   (e_timeout h t)
                   gst.
    exists gst'.
    by eapply LTimeout; eauto.
  Qed.

  (* tick is eventually delivered. *)
  (* request is only delivered if the query it's attached to isn't. *)
  Lemma Tick_eventually_occurred :
    forall s,
      lb_execution s ->
      strong_local_fairness s ->
      forall h st t,
        In t (timeouts (occ_gst (hd s)) h) ->
        In h (nodes (occ_gst (hd s))) ->
        ~ In h (failed_nodes (occ_gst (hd s))) ->
        sigma (occ_gst (hd s)) h = Some st ->
        timeout_constraint (occ_gst (hd s)) h t ->
        eventually (now (occurred (Timeout h t))) s.
  Proof.
    move => s H_exec H_fair h st t H_in_n H_in_f H_in_m H_s H_constraint.
    set P := eventually _.
    case (classic (P s)) => //.
    rewrite /P {P} => H_ev.
    suff H_suff: inf_occurred (Timeout h t) s by inversion H_suff.
    apply H_fair.
    apply always_inf_often.
    apply not_eventually_always_not in H_ev.
    move: H_ev.
    apply weak_until_always_not_always.
    apply Timeout_enabled_until_occurred; auto.
    move: H_s H_constraint.
    now apply l_enabled_Timeout_In_timeouts.
  Qed.
End LabeledChord.
