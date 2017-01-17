require "selenium-webdriver"
require "watir"
require 'thread'
require 'nokogiri'
require 'mechanize'
class WelcomeController < ApplicationController
  
  skip_before_filter :require_login, :only => :cron_job
  

  def search 
    @marche = []
    Pneumatico.all.each do |item|
      @marche.push(item.marca) unless @marche.include?(item.marca)
    end
    
    @marche_pneumatici = []
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      @marche_pneumatici.push option.text
    end
    file_pneumatici.close
    
  end
  
  def update_results 
    mis = Query.last.misura[0..4]
    misura = mis[0..2]+"/"+mis[3..-1]
    
    raggio = Query.last.misura[5..-1]
    #stagione = params[:stagione]
    puts "UPDATING"
    @res = Pneumatico.where(misura: misura, raggio: raggio).order(:prezzo_netto)
    @results = []
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
    @fornitori = []
    @res.each do |r|
      if !@fornitori.include? r.nome_fornitore
        if r.nome_fornitore == "FarnesePneus"
          @fornitori.push "Farnese"
        elsif r.nome_fornitore == "PendinGomme"
          @fornitori.push "Pendin"
        else
          @fornitori.push r.nome_fornitore
        end
      end
    end
    puts @res.inspect
    respond_to do |format|
        format.js
    end
  end
  
  def index
    @results = {}
    max_results = 300
  
    query = params[:misura].to_i
    @query = query
    # Per ora tolgo la marca
    
    #marca = params[:marca]
    
    marca = ""
    stagione = params[:stagione]
    @stagione = stagione
    # DA AGGIUNGERE SUPPORTO CAMION
    
    if params[:misura].to_i.to_s != params[:misura] || params[:misura].length != 7 
      flash[:alert] = "Ricerca non valida"
      redirect_to root_path
    else
      query_list = [query]
      
      puts query_list
      tmp_misura = query.to_s[0..2]+"/"+query.to_s[3..4]
      tmp_raggio = query.to_s[5..-1]
      @misura = tmp_misura.gsub("/","")
      @raggio = tmp_raggio
      puts tmp_misura
      puts tmp_raggio
      if Query.exists?(misura: query.to_s , stagione: stagione) || Query.exists?(misura: query.to_s, stagione: "Tutte")
        
        puts "La query esiste già"
        @new = false
        if stagione != "Tutte"
          if marca != ""
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni", marca).order(:prezzo_netto)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?)", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni").order(:prezzo_netto)
          end
        else
          if marca != ""
            
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", marca).order(:prezzo_netto)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_netto)
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
        puts inactives
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
        
        Pneumatico.delay.add_to_db(query_list, max_results, stagione)

        if stagione != "Tutte"
          if marca != ""
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni", marca).order(:prezzo_netto)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?)", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni").order(:prezzo_netto)
          end
        else
          if marca != ""
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", marca).order(:prezzo_netto)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_netto)
          end
        end
        
        Query.create(misura: query.to_s , stagione: stagione)
      end  
      k = 0
      while k < 10
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
            else
              @fornitori.push r.nome_fornitore
            end
          end
        end
    end
  end
  
  def cron_job
    query_list = []
    Query.where(tag: "routine").each do |query|
      query_list.push(query.misura)
    end
    Pneumatico.delete_all
    Query.where(tag: nil).delete_all
    #Selenium::WebDriver::PhantomJS.path = Rails.root.join('bin','phantomjs').to_s
    puts query_list
    
    #populate(query_list, 300)
    Pneumatico.delay.add_to_db(query_list, 300)
    redirect_to :root
  end
  
  
private

  
end

