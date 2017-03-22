require "selenium-webdriver"
require "watir"
require 'thread'
require 'nokogiri'
require 'mechanize'
require 'platform-api'
class WelcomeController < ApplicationController
  
  skip_before_filter :require_login, :only => :cron_job
  

  def search 
    @marche = []
    
=begin
    Pneumatico.all.each do |item|
      @marche.push(item.marca) unless @marche.include?(item.marca)
    end
=end

    @marche_pneumatici = []
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      @marche_pneumatici.push option.text
    end
    file_pneumatici.close
    
  end
  
  def update_results 
    marca = params[:marca]
    misura_query = params[:misura]
    # CONTROLLO CHE CI SIA ALMENO UN RISULTATO
    if pneumatico = Pneumatico.where(query: misura_query).first
      
      misura = pneumatico.misura
      raggio = pneumatico.raggio
      stagione = Search.where(misura: misura_query).first.stagione
      
      if stagione != "Tutte"
        if marca != "Tutte"
          @res = Pneumatico.where(misura: misura, raggio: raggio, stagione: stagione , marca: marca).order(:prezzo_finale)
        else
          @res = Pneumatico.where(misura: misura, raggio: raggio, stagione: stagione ).order(:prezzo_finale)
        end
      else
        if marca != "Tutte"
          @res = Pneumatico.where(misura: misura, raggio: raggio, marca: marca).order(:prezzo_finale)
        else
          @res = Pneumatico.where(misura: misura, raggio: raggio).order(:prezzo_finale)
        end
      end
     
      
      #@results = []
      @fornitori = []
      inactives = []
      if !@res.nil?
        Fornitore.all.each do |el|
          if el.status == "Disattivato"
            if el.nome == "MultiTyre"
              inactives.push "MultiTires"
            else
              inactives.push el.nome
            end
            puts el.nome
          end
        end
        @res.each do |item|
          if inactives.include? item.nome_fornitore 
            puts "removing"
            puts item
            @res.delete item
          end
        end
            #puts @res.inspect
        
        @res.each do |r|
          if !@fornitori.include? r.nome_fornitore
            if r.nome_fornitore == "FarnesePneus"
              @fornitori.push "Farnese"
            elsif r.nome_fornitore == "PendinGomme"
              @fornitori.push "Pendin"
            elsif r.nome_fornitore == "CarliniGomme"
              @fornitori.push "Carlini"
            else
              @fornitori.push r.nome_fornitore
            end
          end
        end
        #puts @res.inspect
        
      end
    end
    
    @finished = Search.where(misura: misura_query).first.finished
    puts @finished
    respond_to do |format|
        format.js
    end
    
=begin
      
    if Search.last.misura.length == 7
      mis = Search.last.misura[0..4]
      misura = mis
      
      raggio = Search.last.misura[5..-1]
      stagione = Search.last.stagione
    else
      mis = Search.last.misura
      if mis.length == 5 && mis[2] == '0'
          raggio = mis[-2..-1]
          misura = mis.gsub(raggio, "")
        else
          raggio = mis[-3..-1]
          misura = mis.gsub(raggio, "")
      end
      
    end
    #stagione = params[:stagione]
    puts "UPDATING"
    if stagione != "Tutte"
      @res = Pneumatico.where(misura: misura, raggio: raggio, stagione: stagione).order(:prezzo_finale)
    else
      @res = Pneumatico.where(misura: misura, raggio: raggio).order(:prezzo_finale)
    end
=end
  end
  
  def index
    
    #heroku = Heroku::API.new(:api_key => "5681181a-1f63-4619-b3fd-832be797e7ca")
    @results = {}
    max_results = 300
  
    query = params[:misura].to_i
    @query = query
    @veicolo = params[:veicolo]
    
  
    # Per ora tolgo la marca
    
    @marca_query = params[:marca]
    
    stagione = params[:stagione]
    @stagione = stagione
    # DA AGGIUNGERE SUPPORTO CAMION
    puts params[:misura].length
    if (params[:misura].to_i.to_s != params[:misura]) || (@veicolo == "leggero" && params[:misura].length != 7) || (@veicolo == "pesante" && params[:misura].length > 8) || (@veicolo == "pesante" && params[:misura].length < 4) 
      flash.now[:alert] = "Ricerca non valida"
      redirect_to root_path
    else
      query_list = [query]
      
      puts query_list
      if query.to_s.length == 7
        tmp_misura = query.to_s[0..4]
        tmp_raggio = query.to_s[5..-1]
      else
        mis = query.to_s
        if mis.length == 5 && mis[2] == '0'
          tmp_raggio = mis[-2..-1]
          tmp_misura = mis.gsub(tmp_raggio, "")

        else
          tmp_raggio = mis[-3..-1]
          tmp_misura = mis.gsub(tmp_raggio, "")
        end
      end
      
      @misura = tmp_misura.gsub("/","")
      @raggio = tmp_raggio
      puts tmp_misura
      puts tmp_raggio
      if Search.exists?(misura: query.to_s , stagione: stagione) || Search.exists?(misura: query.to_s, stagione: "Tutte")
        
        puts "La query esiste già"
        @new = false
        if stagione != "Tutte"
          if @marca_query != "Tutte"
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ? ) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, @marca_query).order(:prezzo_finale)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ? )", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione).order(:prezzo_finale)
          end
        else
          if @marca_query != "Tutte"
            
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", @marca_query).order(:prezzo_finale)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_finale)
          end
        end
        inactives = []
        Fornitore.where(status: "Disattivato").each do |el|
          if el.nome == "MultiTyre"
            inactives.push "MultiTires"
          else
            inactives.push el.nome
          end
        end
        
        @res.each do |item|
          if inactives.include? item.nome_fornitore 
            puts "removing"
            puts item
            @res.delete item
          end
        end
        #puts @res.inspect
       
      else
        Watir.default_timeout = 30
        @new = true
    
        #Selenium::WebDriver::PhantomJS.path = '/bin/phantomjs'  #Rails.root.join('bin','phantomjs').to_s || 
        
        # MOVE THE LOGIC TO MODEL
        
        #populate(query_list, max_results, stagione)
        
        # SEZIONE CRITICA DA PROTEGGERE - DUE PROCESSI POTREBBERO ARRIVARE INSIEME A QUESTO PUNTO E SCAMBIARSI GLI ID
        
        #actual_workers = heroku.get_dyno_types('wikityres').body.second["quantity"]
        
        Pneumatico.delay.add_to_db(query_list, max_results, stagione)
        
        
        #heroku.post_ps_scale('wikityres', 'worker', worker_id)
        PlatformAPI.connect_oauth("5681181a-1f63-4619-b3fd-832be797e7ca").dyno.create("wikityres",{command: 'rake jobs:workoff', size: 'performance-M'})
        
        if stagione != "Tutte"
          if @marca_query != "Tutte"
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni", @marca_query).order(:prezzo_finale)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?)", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni").order(:prezzo_finale)
          end
        else
          if @marca_query != "Tutte"
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", @marca_query).order(:prezzo_finale)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_finale)
          end
        end
        
        Search.create(misura: query.to_s , stagione: stagione, finished: false)
        puts Search.last.inspect
      end  
      k = 0
      while k < 8
        ActiveRecord::Base.connection.clear_query_cache
        puts Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).count
        if Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).count < 1
          sleep 3
        else
          break
        end
        k+=1
      end
      @fornitori = []
      @res.each do |r|
          if !@fornitori.include? r.nome_fornitore
            if r.nome_fornitore == "FarnesePneus"
              @fornitori.push "Farnese"
            elsif r.nome_fornitore == "PendinGomme"
              @fornitori.push "Pendin"
            elsif r.nome_fornitore == "CarliniGomme"
              @fornitori.push "Carlini"
            else
              @fornitori.push r.nome_fornitore
            end
          end
        end
    end
  end
  
  def cron_job
    Pneumatico.delete_all
    Search.where(tag: nil).delete_all
    query_list = []
   
    Search.where(tag: "routine").each do |query|
        query_list.push(query.misura)
    end
    tmp_list = []
    puts "LIST:"
    puts query_list
    query_list.each do |item|
      tmp_list = [item]
      Pneumatico.delay.add_to_db(tmp_list, 300)
      PlatformAPI.connect_oauth("5681181a-1f63-4619-b3fd-832be797e7ca").dyno.create("wikityres",{command: 'rake jobs:workoff'})
    end
    #Selenium::WebDriver::PhantomJS.path = Rails.root.join('bin','phantomjs').to_s

    
    #populate(query_list, 300)
    
    redirect_to :root
  end
  
  
private

  
end

