locals { 
    plan_index = format("%02d", floor((var.team_id - 1) / 4) + 1) 
    team_name  = format("%03d", var.team_id) 
}
